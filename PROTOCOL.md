# ColorFit Icon 4 — BLE Protocol (CrRePa/Jieli CRP)

Complete reverse-engineering of the Noise ColorFit Icon 4 smartwatch BLE protocol.

## Status: CONFIRMED

All protocol details verified via live BLE communication and APK decompilation.

## Device Info (example values)

| Field | Example |
|-------|---------|
| Device Name | ColorFit Icon 4 |
| Manufacturer | MOYOUNG-R |
| Firmware | JLQFNHTK1.0 |
| Hardware | MOY-V8Y3-2.0.0 |
| Chipset | CrRePa / Jieli CRP |

## BLE GATT Services

| Service | UUID | Purpose |
|---------|------|---------|
| GAP | 0x1800 | Device name |
| GATT | 0x1801 | Service changed |
| Heart Rate | 0x180D | Standard HR |
| Battery | 0x180F | Battery level |
| Device Info | 0x180A | Serial/FW/HW |
| Vendor EEA | 0xFEEA | Main CrRePa service |
| Vendor EE7 | 0xFEE7 | ECG data |
| Vendor 190E | 0x190E | Unknown |
| Vendor AE00 | 0xAE00 | NoiseFit data |

## Characteristics

### Write (phone → watch)
| UUID | Role |
|------|------|
| **fee2** | **Primary write** (CONFIRMED) |
| fee5 | Alternate write |
| fee6 | Secondary write |

### Notify (watch → phone)
| UUID | Role |
|------|------|
| **fee3** | **Main response** (CONFIRMED) |
| fee1 | Step data |
| fee9 | Additional |

### Standard
| UUID | Role |
|------|------|
| 2a19 | Battery level (read) |
| 2a37 | Heart rate measurement (notify) |

## Packet Format

```
[FE] [EA] [flags] [length] [cmd] [payload...]
```

| Byte | Value | Description |
|------|-------|-------------|
| 0 | 0xFE | Magic byte 1 |
| 1 | 0xEA | Magic byte 2 |
| 2 | 0x10 or 0x20 | Flags (0x10 for MTU≤20, 0x20 normal) |
| 3 | N | Total packet length |
| 4 | CMD | Command type byte |
| 5+ | ... | Payload data |

## Command Types

| Cmd | Hex | Description |
|-----|-----|-------------|
| 0x32 | 50 | Today's steps |
| 0x37 | 55 | Today's HR |
| 0xAB | 171 | HR history |
| 0xBC | 188 | Sleep data |
| 0xB2 | 178 | Step detail |
| 0x33 | 51 | Step history |
| 0x31 | 49 | Time sync |
| 0x2E | 46 | Device version |
| 0x2A | 42 | Metric system |
| 0x81 | 129 | Bond state |
| 0x77 | 119 | Create bond |
| 0xF8 | 248 | Remove bond |

## HR History Response (cmd 0xAB, sub-type 0)

**Payload layout:**
| Offset | Field | Description |
|--------|-------|-------------|
| [0] | sub_type | 0 = HR history |
| [1] | packet_index | Sequence number |
| [2] | HR[0] | Heart rate BPM (unsigned byte) |
| [3..6] | TS[0] | Timestamp (little-endian uint32, seconds since epoch) |
| [7] | HR[1] | Next HR reading |
| [8..11] | TS[1] | Next timestamp |
| ... | ... | Repeating 5-byte records |

## Example Response

```
FE EA 20 2A AB 00 07 68 B5 2A 67 6A 6C ED 2A 67 6A ...
```

Parsed:
- cmd = 0xAB (HR history)
- sub_type = 0 (history HR)
- packet_index = 7
- 7 HR readings with timestamps

## Usage

```bash
# Build
go build -o bin/noise-watch-client ./cmd/noise-watch-client/

# Find watch MAC
bluetoothctl scan on
bluetoothctl devices

# Connect and read data
bin/noise-watch-client -addr XX:XX:XX:XX:XX:XX
```

## Notes

- Write to **fee2**, read responses from **fee3**
- BLE only allows one connection at a time
- Timestamps are in GMT+8 (watch firmware timezone)
- See [README.md](README.md) for full project documentation
