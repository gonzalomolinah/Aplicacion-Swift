import SwiftUI

struct ContentView: View {

    @StateObject var ble = BLEManager()

    var body: some View {
        VStack(spacing: 30) {

            Text("Mochila Segura")
                .font(.largeTitle)

            Text("Estado:")
                .font(.headline)

            Text(ble.status)
                .font(.title2)
                .foregroundColor(ble.status == "ALARM" ? .red : .green)

            Button("ARMAR") {
                ble.sendCommand("ARM")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!ble.connected)

            Button("DESARMAR") {
                ble.sendCommand("DISARM")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!ble.connected)
        }
        .padding()
    }
}
