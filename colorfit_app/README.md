# Noise ColorFit Icon 4 — Flutter App & Reverse-Engineered BLE Protocol Client

A reverse-engineered, cloud-free Flutter companion app and protocol documentation for the **Noise ColorFit Icon 4** smartwatch (Jieli MCU / MOYOUNG CrRePa platform).

---

## 📊 Status & Feature Summary

### ✅ What Works
| Feature | Status | Details |
|---|---|---|
| **BLE Scanning & Pairing** | ✅ Working | Auto-filters connected devices, MAC `EB:82:96:7B:74:3B` session persistence |
| **Battery Monitoring** | ✅ Working | Real-time percentage read via standard BLE service (`0x180F`) |
| **Live Heart Rate** | ✅ Working | Real-time BPM streaming (`0x2A37`) |
| **Heart Rate History** | ✅ Working | Timestamped BPM logs via CrRePa command `0xAB` |
| **Step / Distance / Calorie History** | ✅ Working | Daily activity metrics via CrRePa command `0x33` |
| **Time Synchronization** | ✅ Working | Epoch timestamp sync via CrRePa command `0x31` (Big-Endian Unix format) |
| **Timezone Sync** | ✅ Working | UTC offset alignment via CrRePa command `0xBB` |
| **12h / 24h Time System Toggle** | ✅ Working | AM/PM / 24h mode via CrRePa command `0x17` |
| **Watch Face Layout Overlay** | ✅ Working | Time/Date/Step overlay positioning via command `0x38` |
| **ROM Built-in Face Switching** | ✅ Working | Switches factory ROM faces instantly via `cmd 0x19` / `cmd 0xB4 [35, index]` |
| **Native RGB565 / RLE Renderer** | ✅ Working | `WatchFaceRenderer` renders 240x280 designs with CrRePa RLE compression (`[0x08, 0x21]`) |
| **10 Fancy Watch Face Backgrounds** | ✅ Working | Minimal, Aurora, Fitness Rings, Cyberpunk, Classic Sport, Golden Hour, Deep Ocean, Cherry Blossom, Matrix, Luxury |
| **Custom Photo Picker** | ✅ Working | Gallery photo upload with auto-scaling to 240x280 |

---

### ⚠️ What Needs Work / Known Issues

#### Custom Watch Face Flash Transfer Engine (`uploadCustomWatchFace`)
- **Symptom**: On-screen circular update animation reaches ~80% or fails to complete flash commit, and the background face does not switch.
- **Root Cause**: The MCU on the Jieli CRP platform ([`com.crrepa.c1.d`](file:///home/vasu/Downloads/Exp/decompiled/sources/com/crrepa/c1/d.java)) uses a **watch-driven request-response handshake** over `cmd 0x6E` / `cmd 0x74` responses (`RX: 0x74/0x6E [FF, FF, offset_lo, offset_hi]`). When the app streams chunks blindly without waiting for offset acknowledgments, or misreads `0xFFFF` as a CRC failure, the MCU Flash SPI controller halts the transfer.
- **To Be Done / Next Steps**:
  1. **Implement Full Request-Response Chunk Loop**: Listen to `cmd 0x6E` / `cmd 0x74` responses from the watch and write chunks strictly when requested by the watch's offset pointer.
  2. **Implement Native Jieli SDK via MethodChannel**: Integrate `libbmp_convert.so` and `com.jieli.bmp_convert.BmpConvert` directly from the decompiled APK via a native Android MethodChannel to match the official app's exact binary encoding.

---

## 🛠 Project Structure

```
colorfit_app/
├── lib/
│   ├── main.dart                      # App entry point & Riverpod configuration
│   ├── core/
│   │   ├── ble/
│   │   │   └── bluetooth_service.dart # BLE connection, GATT MTU, packet guards, & transfer protocol
│   │   ├── protocol/
│   │   │   ├── constants.dart        # BLE UUIDs and CrRePa command opcodes
│   │   │   └── parser.dart           # Binary packet builder & payload decoders
│   │   ├── watchface/
│   │   │   └── watch_face_renderer.dart # 240x280 RGB565 / RLE graphics engine & 10 preset designs
│   │   ├── storage/
│   │   │   └── data_storage.dart     # Shared preferences & metrics persistence
│   │   └── theme/
│   │       └── app_theme.dart        # Dark-mode UI styling
│   └── features/
│       ├── home/
│       │   └── home_screen.dart      # Main dashboard & metric widgets
│       ├── metrics/
│       │   └── watch_faces_page.dart # Fancy watch face selector & photo picker
│       ├── device/
│       │   └── device_screen.dart    # Device connection & info panel
│       └── settings/
│           └── settings_screen.dart  # Time format, time sync & configuration
```

---

## 🚀 How to Run & Build

### Prerequisites
- Flutter 3.x SDK
- Android SDK 21+ (Android 5.0 to 14+)
- Device with Bluetooth Low Energy (BLE)

### Commands
```bash
cd colorfit_app
flutter pub get
flutter run
flutter build apk --debug
```
