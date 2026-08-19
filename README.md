# Noise ColorFit Icon 4 — Local BLE Client

A reverse-engineered, cloud-free Go client for the **Noise ColorFit Icon 4** smartwatch.
Reads heart rate, steps, battery, and sleep data directly over Bluetooth LE — no vendor app, no cloud, no account required.

## Why?

The NoiseFit app requires a cloud account, sends your health data to remote servers, and
uses analytics/telemetry. This project gives you **full local control** over your own watch
and health data.

## What's Working

| Feature | Status | Method |
|---------|--------|--------|
| Battery level | ✅ Working | Standard BLE Battery Service (0x180F) |
| Heart rate history | ✅ Working | CrRepa cmd 0xAB — timestamped BPM readings |
| Live heart rate | ✅ Working | Standard HR Measurement (0x2A37) — real-time BPM |
| Step count | ✅ Working | CrRepa cmd 0x33 — steps, distance, calories |
| Time sync | ✅ Working | CrRepa cmd 0x31 — BIG-ENDIAN Unix timestamp |
| Device info | ✅ Working | Standard BLE Device Information Service |
| Sleep data | ⚠️ Command confirmed | CrRePa cmd 0xBC — watch may have no sleep records |

## Hardware

- **Watch:** Noise ColorFit Icon 4
- **Chipset:** CrRepa / Jieli CRP (Chinese BLE SoC)
- **Manufacturer:** MOYOUNG (OEM)
- **Firmware:** JLQFNHTK1.0

## Quick Start

### Prerequisites

- Linux with BlueZ 5.0+ (Ubuntu 20.04+, Fedora 30+, etc.)
- Go 1.21+
- Bluetooth adapter with BLE support

### Build

```bash
git clone https://github.com/yourusername/noise-watch-client.git
cd noise-watch-client
go build -o bin/noise-watch-client ./cmd/noise-watch-client/
```

### Find Your Watch's MAC Address

```bash
# Put your watch in pairing mode (open NoiseFit app → device settings → unpair)
# Then scan:
bluetoothctl scan on
# Wait 15 seconds, then:
bluetoothctl devices
# Look for "ColorFit Icon 4" in the list
```

### Connect and Read Data

```bash
# Replace with your watch's MAC address
bin/noise-watch-client -addr XX:XX:XX:XX:XX:XX
```

Example output:

```
=== Noise ColorFit Watch Client ===
Protocol: CrRepa (Jieli CRP chipset)

Connecting to XX:XX:XX:XX:XX:XX...
Discovered 9 services
  Write char: fee2
  Notify char: fee3
Notifications enabled
Connected! Reading sensor data...

Battery: 90%
Sending bond state...
Requesting heart rate history...
  Response cmd=0xAB payload=37 bytes
  Heart Rate History (7 readings):
    2026-07-27 05:53: 104 BPM
    2026-07-27 05:54: 108 BPM
    2026-07-28 00:56: 80 BPM
    ...
```

### Enumerate GATT Services

```bash
bin/noise-watch-client -addr XX:XX:XX:XX:XX:XX -enumerate
```

## Project Structure

```
noise-watch-client/
├── cmd/
│   └── noise-watch-client/   # Main CLI client
│       └── main.go
├── internal/
│   ├── ble/                   # BLE client (tinygo.org/x/bluetooth)
│   │   └── ble.go
│   └── protocol/              # CrRepa protocol constants & parsing
│       └── protocol.go
├── proto/                     # Reconstructed protobuf schema (reference)
│   └── noise.proto
├── .private/                  # YOUR sensitive data (git-ignored)
│   └── my-device.md
├── PROTOCOL.md                # Full protocol documentation
├── README.md                  # This file
└── LICENSE                    # MIT License
```

## Protocol Overview

The ColorFit Icon 4 uses the **CrRepa** protocol (Jieli/JLQ chipset). Communication is
via BLE GATT with a custom packet format:

```
Packet: [FE] [EA] [flags] [length] [cmd] [payload...]
  0xFE 0xEA  — magic header
  flags      — 0x10 (MTU≤20) or 0x20 (normal)
  length     — total packet length (including header)
  cmd        — command type byte
  payload    — command-specific data
```

### Key Commands

| Cmd | Hex | Description |
|-----|-----|-------------|
| Today's Steps | 0x32 | Get current step count |
| Today's HR | 0x37 | Get today's heart rate |
| HR History | 0xAB | Get historical HR readings |
| Sleep Data | 0xBC | Get sleep stages |
| Device Version | 0x2E | Get firmware info |
| Time Sync | 0x31 | Set watch time |
| Bond State | 0x81 | Pairing handshake |

### BLE Characteristics

| UUID | Role |
|------|------|
| fee2 | Write (phone → watch) |
| fee3 | Notify (watch → phone) |
| 2a19 | Battery level (standard) |
| 2a37 | Heart rate measurement (standard) |

See [PROTOCOL.md](PROTOCOL.md) for the full protocol specification.

## How It Was Reverse-Engineered

1. **APK Decompilation:** Decompile the NoiseFit Android app with jadx to extract
   BLE UUIDs, command structures, and data models from `cn.appscomm.bluetooth` and
   `com.crrepa` packages.

2. **Live GATT Enumeration:** Connect to the watch directly from Linux via BLE and
   enumerate all services/characteristics to confirm UUIDs.

3. **Protocol Testing:** Send commands to the watch and parse responses to validate
   the packet format and command types.

4. **Cross-Reference:** Match decompiled Java code against live responses to build
   a complete protocol specification.

### Tools Used

- [jadx](https://github.com/skylot/jadx) — APK decompiler
- [tinygo.org/x/bluetooth](https://pkg.go.dev/tinygo.org/x/bluetooth) — Go BLE library
- [Wireshark](https://www.wireshark.org/) — BLE packet analysis
- `bluetoothctl` — Linux Bluetooth management

## Limitations

- **Single connection:** BLE only allows one connection at a time. Disconnect from
  the NoiseFit app before using this client.
- **Linux only:** Uses BlueZ D-Bus interface. macOS and Windows are not supported
  by the tinygo bluetooth library.
- **No encryption:** The CrRepa protocol does not appear to use BLE pairing encryption
  for data commands. This means any nearby BLE device could theoretically sniff the traffic.
- **Partial protocol:** Step and sleep command formats are confirmed but response
  parsing is still being developed.

## Contributing

Contributions are welcome! Areas that need work:

- [ ] Parse step count response (cmd 0x32)
- [ ] Parse sleep data response (cmd 0xBC)
- [ ] Implement live heart rate streaming (0x2A37 notifications)
- [ ] Add command-line options for specific data queries
- [ ] Write tests for protocol parsing
- [ ] Support macOS/Windows via alternative BLE libraries

## Privacy & Security

This project communicates directly with your watch over BLE. **No data is sent to
any server.** All processing happens locally on your machine.

The watch's BLE protocol does not appear to use encryption, so nearby devices could
theoretically observe the traffic. This is a limitation of the watch firmware, not
this software.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- Reverse-engineering the NoiseFit APK protocol
- The CrRepa/Jieli CRP BLE chipset documentation community
- [tinygo.org/x/bluetooth](https://pkg.go.dev/tinygo.org/x/bluetooth) for the Go BLE library
