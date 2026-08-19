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
| 0x17 | 23 | Set time system (0=12h, 1=24h) |
| 0x27 | 39 | Query time system |
| 0x2A | 42 | Metric system |
| 0x2E | 46 | Device version |
| 0x31 | 49 | Time sync |
| 0x32 | 50 | Today's steps |
| 0x33 | 51 | Step history |
| 0x37 | 55 | Today's HR |
| 0x5A | 90 | Device info query |
| 0x77 | 119 | Create bond |
| 0x81 | 129 | Bond state |
| 0xAB | 171 | HR history |
| 0xB2 | 178 | Step detail |
| 0xB4 | 180 | Watch face |
| 0xB9 | 185 | SPP handshake |
| 0xBB | 187 | Timezone sync |
| 0xBC | 188 | Sleep data |
| 0xBD | 189 | Reply app query |
| 0xF8 | 248 | Remove bond |

## Connection Init Sequence (CONFIRMED)

After GATT connection and notification enable, send these commands in order:

```
1. SPP Handshake:       FE EA 20 06 B9 0E
2. App Protocol Query:  FE EA 20 07 BD 16 00
3. Device Info Query:   FE EA 20 06 5A 00
4. Time Sync:           FE EA 10 0A 31 XX XX XX XX 08
5. Timezone Sync:       FE EA 10 0B BB 07 00 XX XX XX XX
```

The watch responds to 0x5A with protocol version (e.g., "MOYOUNG-V2").

## Time Sync (cmd 0x31)

Sends current time to the watch.

**Payload (5 bytes):**
| Offset | Field | Description |
|--------|-------|-------------|
| [0..3] | timestamp | Unix timestamp (big-endian uint32, seconds) |
| [4] | day_of_week | Day of week (8 = constant) |

**Example:** `FE EA 10 0A 31 6A 85 3E A0 08`

## Timezone Sync (cmd 0xBB)

Sends timezone offset to the watch.

**Payload (6 bytes):**
| Offset | Field | Description |
|--------|-------|-------------|
| [0] | constant | 7 |
| [1] | constant | 0 |
| [2..5] | offset | Timezone offset in seconds (little-endian int32) |

**Example:** `FE EA 10 0B BB 07 00 E8 03 00 00` (UTC+8 = +28800s)

## Time System (cmd 0x17 / 0x27)

Sets or queries 12/24 hour format.

**Set (cmd 0x17):**
| Offset | Field | Description |
|--------|-------|-------------|
| [0] | format | 0 = 12-hour (AM/PM), 1 = 24-hour |

**Query (cmd 0x27):** No payload. Returns current setting.

## Watch Face (cmd 0xB4)

Switches watch face type.

**Payload:**
| Offset | Field | Description |
|--------|-------|-------------|
| [0] | sub_cmd | 22 = get info, 35 = switch |
| [1] | type | 1 = Photo, 2 = Video |

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

## OTA Protocol (Firmware Update)

The watch uses a separate OTA service for firmware updates:

| Service | UUID | Purpose |
|---------|------|---------|
| OTA Service | 0xAE00 | Firmware update |

| Characteristic | UUID | Role |
|----------------|------|------|
| OTA Write | 0xAE01 | Write OTA commands |
| OTA Notify | 0xAE02 | Receive OTA responses |

### OTA Packet Format

```
[FE] [opcode] [length] [payload...]
```

| Byte | Description |
|------|-------------|
| 0 | Start tag (0xFE) |
| 1 | Opcode |
| 2 | Payload length |
| 3+ | Payload data |

### OTA Opcodes

| Opcode | Hex | Description |
|--------|-----|-------------|
| 0xE1 | 225 | Get firmware version |
| 0xE2 | 226 | Erase flash |
| 0xE3 | 227 | Write data |
| 0xE4 | 228 | Verify checksum |
| 0xE5 | 229 | Reset device |
| 0xE6 | 230 | Get firmware info |
| 0xE7 | 231 | Set baud rate |
| 0xE8 | 232 | Ping/test |

### Capturing OTA Traffic

```bash
# Start capture mode
bin/noise-watch-client -addr XX:XX:XX:XX:XX:XX -ota

# Then initiate firmware update from NoiseFit app
# Capture saved to ota_capture.log
```

## Bond State Command (0x81)

| Payload | Description |
|---------|-------------|
| `04 01` | Bonded |
| `04 00` | Unbonded |

Response from watch: `04 XX` where XX = 0 (unbonded), 1 (bonded), 2 (bonding)

## Create Bond Command (0x77)

| Payload | Description |
|---------|-------------|
| `04` + MAC(6 bytes) | Bond with device |

Example: `FE EA 20 0C 77 04 EB 82 96 7B 74 3B`

- Write to **fee2**, read responses from **fee3**
- BLE only allows one connection at a time
- Timestamps are in GMT+8 (watch firmware timezone)
- See [README.md](README.md) for full project documentation
