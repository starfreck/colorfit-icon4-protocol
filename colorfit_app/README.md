# ColorFit Icon 4 — Flutter App

A cross-platform Flutter app for the Noise ColorFit Icon 4 smartwatch.

## Features

- **BLE Connection** — Connect to your watch via Bluetooth Low Energy
- **Health Dashboard** — View steps, heart rate, distance, calories
- **Live Heart Rate** — Real-time BPM monitoring
- **Time Sync** — Sync watch time with your phone
- **Custom UI** — Dark tech aesthetic with gradient cards

## Architecture

```
lib/
├── core/
│   ├── ble/           # BLE service layer
│   ├── protocol/      # CrRePa protocol parser
│   └── theme/         # App theme & colors
├── data/
│   ├── models/        # Data models
│   └── repositories/  # Data repositories
└── features/
    ├── home/          # Dashboard screen
    ├── device/        # Device connection
    └── settings/      # App settings
```

## Getting Started

### Prerequisites

- Flutter 3.0+
- Android Studio / Xcode
- Physical device with BLE support

### Setup

```bash
cd colorfit_app
flutter pub get
flutter run
```

### Permissions

**Android** — Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

**iOS** — Add to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to your watch</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to your watch</string>
```

## Dependencies

- `flutter_blue_plus` — BLE communication
- `flutter_riverpod` — State management
- `flutter_animate` — Animations
- `google_fonts` — Typography

## TODO

- [ ] Connect to real BLE device
- [ ] Implement live HR streaming
- [ ] Add sleep data view
- [ ] Cloud sync integration
- [ ] Export health data
