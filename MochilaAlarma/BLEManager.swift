import Foundation
import CoreBluetooth
import Combine

@MainActor
final class BLEManager: NSObject, ObservableObject {

    enum ConnectionState: String {
        case bluetoothOff = "BLUETOOTH APAGADO"
        case idle = "DESCONECTADO"
        case scanning = "BUSCANDO DISPOSITIVO..."
        case connecting = "CONECTANDO..."
        case connected = "CONECTADO"
        case notFound = "NO ENCONTRADO (REINTENTANDO...)"
        case error = "ERROR DE CONEXIÓN"
    }

    // MARK: - Published UI State
    @Published var status: String = ConnectionState.idle.rawValue
    @Published var connected: Bool = false
    @Published var bluetoothReady: Bool = false
    @Published var lastError: String?
    @Published var isBusy: Bool = false
    @Published var logs: [String] = []
    @Published var lastRSSI: Int?

    private let maxLogs = 250

    // MARK: - BLE
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?

    private let targetPeripheralName = "Mochila-Alarma"
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890ab")
    private let commandUUID = CBUUID(string: "abcd0001-1234-1234-1234-1234567890ab")
    private let stateUUID   = CBUUID(string: "abcd0002-1234-1234-1234-1234567890ab")

    private var commandChar: CBCharacteristic?
    private var scanTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
        addLog("BLEManager inicializado")
    }

    private func addLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)"
        logs.insert(line, at: 0)
        if logs.count > maxLogs {
            logs.removeLast(logs.count - maxLogs)
        }
    }

    func clearLogs() {
        logs.removeAll()
        addLog("Logs limpiados")
    }

    func start() {
        guard bluetoothReady else { return }
        startScanIfNeeded()
    }

    func sendCommand(_ cmd: String) {
        guard connected,
              let peripheral,
              let commandChar else {
            lastError = "No hay conexión BLE disponible."
            addLog("No se pudo enviar '\(cmd)': sin conexión")
            return
        }

        isBusy = true
        lastError = nil
        addLog("Enviando comando: \(cmd)")

        guard let data = cmd.data(using: .utf8) else {
            lastError = "No se pudo codificar el comando."
            isBusy = false
            addLog("Error codificando comando: \(cmd)")
            return
        }

        peripheral.writeValue(data, for: commandChar, type: .withResponse)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.isBusy {
                self.isBusy = false
                self.lastError = "Timeout esperando respuesta del dispositivo"
                self.addLog("Timeout de respuesta para comando: \(cmd)")
            }
        }
    }

    func reconnect() {
        addLog("Reconexión manual solicitada")
        disconnectCurrentIfNeeded()
        startScanIfNeeded(force: true)
    }

    func requestStatus() {
        sendCommand("STATUS")
    }

    func ping() {
        sendCommand("PING")
    }

    private func disconnectCurrentIfNeeded() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil

        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }

        commandChar = nil
        connected = false
    }

    private func startScanIfNeeded(force: Bool = false) {
        guard central.state == .poweredOn else {
            bluetoothReady = false
            status = ConnectionState.bluetoothOff.rawValue
            return
        }

        guard force || !central.isScanning else { return }

        status = ConnectionState.scanning.rawValue
        connected = false
        commandChar = nil
        lastError = nil
        addLog("Iniciando escaneo BLE")

        // Escaneo amplio para no depender de un advertising incompleto.
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        scanTimeoutTask?.cancel()
        scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self else { return }
            if self.central.isScanning, self.peripheral == nil {
                self.status = ConnectionState.notFound.rawValue
                self.addLog("No se encontró dispositivo en 10s; reintentando")
                self.central.stopScan()
                self.startScanIfNeeded(force: true)
            }
        }
    }

    private func connect(to peripheral: CBPeripheral) {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil

        self.peripheral = peripheral
        status = ConnectionState.connecting.rawValue
        addLog("Conectando a \(peripheral.name ?? "periférico BLE")")
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    private func peripheralMatches(_ peripheral: CBPeripheral,
                                   advertisementData: [String: Any]) -> Bool {
        if peripheral.name == targetPeripheralName {
            return true
        }

        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
           localName == targetPeripheralName {
            return true
        }

        if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           services.contains(serviceUUID) {
            return true
        }

        return false
    }
}

extension BLEManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                self.bluetoothReady = true
                self.addLog("Bluetooth encendido")
                self.startScanIfNeeded()
            case .poweredOff:
                self.bluetoothReady = false
                self.status = ConnectionState.bluetoothOff.rawValue
                self.addLog("Bluetooth apagado")
                self.disconnectCurrentIfNeeded()
            case .unauthorized:
                self.bluetoothReady = false
                self.status = "BLUETOOTH SIN PERMISO"
                self.lastError = "Revisa permisos de Bluetooth en Ajustes."
                self.addLog("Bluetooth sin permiso")
                self.disconnectCurrentIfNeeded()
            case .unsupported:
                self.bluetoothReady = false
                self.status = "BLUETOOTH NO SOPORTADO"
                self.disconnectCurrentIfNeeded()
            default:
                self.bluetoothReady = false
                self.status = ConnectionState.idle.rawValue
                self.disconnectCurrentIfNeeded()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String : Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor in
            self.lastRSSI = RSSI.intValue
            guard self.peripheral == nil else { return }
            if self.peripheralMatches(peripheral, advertisementData: advertisementData) {
                self.addLog("Dispositivo detectado (RSSI: \(RSSI))")
                self.connect(to: peripheral)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connected = true
            self.status = ConnectionState.connected.rawValue
            self.lastError = nil
            self.addLog("Conexión BLE establecida")
            peripheral.delegate = self
            peripheral.discoverServices([self.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            self.connected = false
            self.commandChar = nil
            self.peripheral = nil
            self.isBusy = false

            if let error {
                self.lastError = "Desconectado: \(error.localizedDescription)"
                self.addLog("Desconectado con error: \(error.localizedDescription)")
            } else {
                self.addLog("Desconectado")
            }

            self.status = ConnectionState.idle.rawValue
            self.startScanIfNeeded(force: true)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            self.connected = false
            self.commandChar = nil
            self.peripheral = nil
            self.isBusy = false
            self.status = ConnectionState.error.rawValue
            self.lastError = error?.localizedDescription ?? "Error desconocido"
            self.addLog("Falló conexión: \(self.lastError ?? "desconocido")")
            self.startScanIfNeeded(force: true)
        }
    }
}

extension BLEManager: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = "Error servicios BLE: \(error.localizedDescription)"
                return
            }

            guard let services = peripheral.services else { return }
            self.addLog("Servicios descubiertos: \(services.count)")
            for service in services where service.uuid == self.serviceUUID {
                peripheral.discoverCharacteristics([self.commandUUID, self.stateUUID], for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = "Error características BLE: \(error.localizedDescription)"
                return
            }

            guard let chars = service.characteristics else { return }
            self.addLog("Características descubiertas: \(chars.count)")

            for char in chars {
                if char.uuid == self.commandUUID {
                    self.commandChar = char
                }
                if char.uuid == self.stateUUID {
                    peripheral.setNotifyValue(true, for: char)
                    peripheral.readValue(for: char)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = "Error actualización BLE: \(error.localizedDescription)"
                return
            }

            guard let data = characteristic.value,
                  let text = String(data: data, encoding: .utf8) else { return }

            self.status = text
            self.isBusy = false
            self.addLog("Estado recibido: \(text)")
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didWriteValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = "Error enviando comando: \(error.localizedDescription)"
                self.isBusy = false
                self.addLog("Error en write BLE: \(error.localizedDescription)")
            } else {
                self.addLog("Comando escrito en BLE correctamente")
            }
        }
    }
}
