import SwiftUI

struct ContentView: View {

    @StateObject private var ble = BLEManager()

    var body: some View {
        VStack(spacing: 16) {
            Text("Mochila Segura")
                .font(.largeTitle)
                .bold()

            GroupBox("Estado") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(ble.connected ? .green : .orange)
                            .frame(width: 10, height: 10)
                        Text(ble.status)
                            .font(.headline)
                    }

                    HStack(spacing: 12) {
                        Text("Bluetooth: \(ble.bluetoothReady ? "OK" : "No listo")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let rssi = ble.lastRSSI {
                            Text("RSSI: \(rssi)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if ble.isBusy {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Procesando comando...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let lastError = ble.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button("ARMAR") { ble.sendCommand("ARM") }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!ble.connected || ble.isBusy)

                Button("DESARMAR") { ble.sendCommand("DISARM") }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!ble.connected || ble.isBusy)
            }

            HStack(spacing: 10) {
                Button("REINTENTAR") { ble.reconnect() }
                    .buttonStyle(.bordered)
                    .disabled(!ble.bluetoothReady)

                Button("PEDIR STATUS") { ble.requestStatus() }
                    .buttonStyle(.bordered)
                    .disabled(!ble.connected || ble.isBusy)

                Button("PING") { ble.ping() }
                    .buttonStyle(.bordered)
                    .disabled(!ble.connected || ble.isBusy)
            }

            GroupBox("Log de desarrollo") {
                VStack(spacing: 8) {
                    HStack {
                        Text("Eventos recientes: \(ble.logs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Limpiar") { ble.clearLogs() }
                            .font(.caption)
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(ble.logs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.caption2, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .padding()
        .onAppear {
            ble.start()
        }
    }
}

#Preview {
    ContentView()
}
