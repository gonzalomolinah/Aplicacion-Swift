import Foundation
import CoreBluetooth
import Combine


class BLEManager: NSObject, ObservableObject {

    // MARK: - Published UI State
    @Published var status: String = "DESCONECTADO"
    @Published var connected: Bool = false

    // MARK: - BLE
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?

    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890ab")
    private let commandUUID = CBUUID(string: "abcd0001-1234-1234-1234-1234567890ab")
    private let stateUUID   = CBUUID(string: "abcd0002-1234-1234-1234-1234567890ab")

    private var commandChar: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func sendCommand(_ cmd: String) {
        guard let peripheral = peripheral,
              let commandChar = commandChar else { return }

        let data = cmd.data(using: .utf8)!
        peripheral.writeValue(data, for: commandChar, type: .withResponse)
    }
}

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            status = "BUSCANDO..."
            central.scanForPeripherals(withServices: [serviceUUID], options: nil)
        } else {
            status = "BLUETOOTH APAGADO"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        print("Descubierto: \(peripheral.name ?? "sin nombre") - RSSI: \(RSSI)")
        
        if peripheral.name == "Mochila-Alarma" {
            print("Encontrado Mochila-Alarma!")
            self.peripheral = peripheral
            central.stopScan()
            status = "CONECTANDO..."
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {

        print("Conectado a Mochila-Alarma!")
        self.connected = true
        self.status = "CONECTADO"
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("Desconectado del periférico")
        DispatchQueue.main.async {
            self.connected = false
            self.status = "DESCONECTADO"
        }
        // Reintentar después de 2 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if central.state == .poweredOn {
                self.status = "BUSCANDO..."
                central.scanForPeripherals(withServices: [self.serviceUUID], options: nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        print("Error al conectar: \(error?.localizedDescription ?? "desconocido")")
        DispatchQueue.main.async {
            self.status = "ERROR CONEXIÓN"
        }
        // Reintentar
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if central.state == .poweredOn {
                self.status = "BUSCANDO..."
                central.scanForPeripherals(withServices: [self.serviceUUID], options: nil)
            }
        }
    }
}

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {

        guard let services = peripheral.services else { return }

        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([commandUUID, stateUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {

        guard let chars = service.characteristics else { return }

        for char in chars {
            if char.uuid == commandUUID {
                commandChar = char
            }
            if char.uuid == stateUUID {
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {

        guard let data = characteristic.value,
              let text = String(data: data, encoding: .utf8) else { return }

        DispatchQueue.main.async {
            self.status = text
        }
    }
}
