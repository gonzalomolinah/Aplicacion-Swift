import SwiftUI

struct ContentView: View {

    @StateObject private var ble = BLEManager()

    var body: some View {
        VStack(spacing: 20) {
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

            HStack(spacing: 12) {
                Button("ARMAR") {
                    ble.sendCommand("ARM")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!ble.connected || ble.isBusy)

                Button("DESARMAR") {
                    ble.sendCommand("DISARM")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!ble.connected || ble.isBusy)
            }

            Button("REINTENTAR CONEXIÓN") {
                ble.reconnect()
            }
            .buttonStyle(.bordered)
            .disabled(!ble.bluetoothReady)
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
