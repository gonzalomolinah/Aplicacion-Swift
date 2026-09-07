# Aplicacion-Swift (MochilaAlarma)

App iOS (SwiftUI + CoreBluetooth) para controlar la alarma BLE de la mochila.

## Cambios principales

- Manejo de estado BLE más robusto (`DESCONECTADO`, `BUSCANDO`, `CONECTANDO`, etc.).
- Reintentos automáticos de escaneo/conexión.
- Escaneo menos frágil (no depende solo de `withServices`).
- Detección del periférico por nombre local o UUID de servicio.
- Feedback visual en UI: progreso, errores y botón de reconexión.
- Panel de log en la app (eventos BLE con timestamp + limpieza manual).
- Herramientas de desarrollo: botones `PING` y `PEDIR STATUS`.
- Lectura inicial de característica de estado al conectar.

## Requisitos

- iOS con Bluetooth habilitado.
- Permisos de Bluetooth en `Info.plist`:
  - `NSBluetoothAlwaysUsageDescription`
  - `NSBluetoothPeripheralUsageDescription`

## Flujo esperado

1. La app inicia y comienza escaneo.
2. Encuentra `Mochila-Alarma` y conecta.
3. Descubre características y se suscribe al estado.
4. Botones `ARMAR` / `DESARMAR` envían comandos BLE y muestran estado.
