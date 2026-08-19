// Package protocol defines constants, UUIDs, and types for the ColorFit Icon 4
// smartwatch BLE protocol (CrRePa/Jieli CRP chipset).
//
// Status: ALL CONFIRMED via live BLE communication + decompiled CrRePa code.
package protocol

import (
	"encoding/binary"
	"fmt"
	"time"
)

// BLE GATT UUIDs — CONFIRMED via live enumeration.
var (
	// Write (phone → watch)
	WriteCharUUID = "0000fee2-0000-1000-8000-00805f9b34fb"
	WriteCharAlt  = "0000fee5-0000-1000-8000-00805f9b34fb"

	// Notify (watch → phone)
	NotifyCharUUID = "0000fee3-0000-1000-8000-00805f9b34fb"
	NotifyChar1    = "0000fee1-0000-1000-8000-00805f9b34fb"

	// Standard BLE
	StdBattLevelChar = "00002a19-0000-1000-8000-00805f9b34fb"
	StdHRMeasChar    = "00002a37-0000-1000-8000-00805f9b34fb"
)

// CrRePa frame format — CONFIRMED.
const (
	FrameMagic1    byte = 0xFE
	FrameMagic2    byte = 0xEA
	FrameLenMTU20  byte = 0x10
	FrameLenNormal byte = 0x20
	FrameHeaderLen      = 5
)

// Command types — CONFIRMED from CrRePa protocol + live testing.
const (
	CmdTodaySteps    byte = 0x32 // Today's steps (ack only, data on fee1)
	CmdStepHistory   byte = 0x33 // Step history (response on fee3)
	CmdTodayHR       byte = 0x37 // Today's HR
	CmdSleepData     byte = 0xBC // Sleep data
	CmdStepDetail    byte = 0xB2 // Step detail for specific day
	CmdHRHistory     byte = 0xAB // HR history (CONFIRMED working)
	CmdTimeSync      byte = 0x31 // Time sync (BIG-ENDIAN Unix timestamp)
	CmdTimeSystem    byte = 0x27 // Query 12/24h format
	CmdDeviceVersion byte = 0x2E // Device version
	CmdMetricSystem  byte = 0x2A // Metric/imperial
	CmdBondState     byte = 0x81 // Bond state
	CmdCreateBond    byte = 0x77 // Create bond
	CmdRemoveBond    byte = 0xF8 // Remove bond
	CmdTimezone      byte = 0xBB // Timezone sync
)

// Sleep stage constants — CONFIRMED from CRPSleepInfo.java.
const (
	SleepAwake    byte = 0 // Sober/awake
	SleepLight    byte = 1 // Light sleep
	SleepDeep     byte = 2 // Deep/restful sleep
	SleepREM      byte = 3 // REM sleep
)

func SleepStageName(stage byte) string {
	switch stage {
	case SleepAwake:
		return "Awake"
	case SleepLight:
		return "Light Sleep"
	case SleepDeep:
		return "Deep Sleep"
	case SleepREM:
		return "REM"
	default:
		return fmt.Sprintf("Unknown(%d)", stage)
	}
}

// HeartRateRecord represents a single HR measurement with timestamp.
type HeartRateRecord struct {
	Timestamp time.Time
	BPM       int
}

// StepRecord represents daily step summary.
type StepRecord struct {
	Steps    uint32
	Distance uint32
	Calories uint32
}

// SleepRecord represents a sleep segment.
type SleepRecord struct {
	Stage     byte
	Hour      int
	Minute    int
	StartMin  int // minutes since midnight
	EndMin    int // minutes since midnight (for history)
}

// BuildPacket creates a CrRePa protocol packet.
func BuildPacket(cmd byte, payload []byte) []byte {
	payloadLen := len(payload)
	totalLen := FrameHeaderLen + payloadLen
	pkt := make([]byte, totalLen)
	pkt[0] = FrameMagic1
	pkt[1] = FrameMagic2
	if totalLen <= 20 {
		pkt[2] = FrameLenMTU20
	} else {
		pkt[2] = FrameLenNormal
	}
	pkt[3] = byte(totalLen)
	pkt[4] = cmd
	if payloadLen > 0 {
		copy(pkt[5:], payload)
	}
	return pkt
}

// ParsePacket parses a CrRePa response.
func ParsePacket(data []byte) (cmd byte, payload []byte, err error) {
	if len(data) < FrameHeaderLen {
		return 0, nil, fmt.Errorf("too short: %d", len(data))
	}
	if data[0] != FrameMagic1 || data[1] != FrameMagic2 {
		return 0, nil, fmt.Errorf("bad magic: %02x %02x", data[0], data[1])
	}
	cmd = data[4]
	if len(data) > FrameHeaderLen {
		payload = data[FrameHeaderLen:]
	}
	return cmd, payload, nil
}

// ParseHRHistory parses HR history response (cmd 0xAB, sub-type 0).
// Format: [sub_type=0] [packet_index] [HR, TS_LE32] ...
func ParseHRHistory(payload []byte) ([]HeartRateRecord, error) {
	if len(payload) < 7 || payload[0] != 0 {
		return nil, fmt.Errorf("not HR history sub-type 0")
	}
	var records []HeartRateRecord
	for i := 2; i+4 < len(payload); i += 5 {
		bpm := int(payload[i] & 0xFF)
		ts := binary.LittleEndian.Uint32(payload[i+1 : i+5])
		records = append(records, HeartRateRecord{
			Timestamp: time.Unix(int64(ts), 0),
			BPM:       bpm,
		})
	}
	return records, nil
}

// ParseStepData parses step data from fee1 notification.
// Format: [steps_3LE] [distance_3LE] [calories_3LE] [time_3LE (optional)]
func ParseStepData(data []byte) (*StepRecord, error) {
	if len(data) < 9 {
		return nil, fmt.Errorf("step data too short: %d", len(data))
	}
	return &StepRecord{
		Steps:    decodeUint24LE(data[0:3]),
		Distance: decodeUint24LE(data[3:6]),
		Calories: decodeUint24LE(data[6:9]),
	}, nil
}

// ParseSleepResponse parses sleep response from cmd 0x33 or fee1.
// Format: [day_type] [state, hour, minute] ...
func ParseSleepResponse(payload []byte) ([]SleepRecord, error) {
	if len(payload) < 4 {
		return nil, fmt.Errorf("sleep data too short")
	}
	// Skip first byte (day type)
	data := payload[1:]
	return parseSleepRecords(data)
}

// ParseSleepHistory parses sleep history from cmd 0xBC.
// Format: [state, hour, minute] ... (3 bytes per record)
func ParseSleepHistory(payload []byte) ([]SleepRecord, error) {
	return parseSleepRecords(payload)
}

func parseSleepRecords(data []byte) ([]SleepRecord, error) {
	if len(data) < 3 || len(data)%3 != 0 {
		return nil, fmt.Errorf("sleep data invalid length: %d", len(data))
	}
	var records []SleepRecord
	for i := 0; i+2 < len(data); i += 3 {
		records = append(records, SleepRecord{
			Stage:  data[i],
			Hour:   int(data[i+1]),
			Minute: int(data[i+2]),
		})
	}
	return records, nil
}

// ParseLiveHR parses standard BLE Heart Rate Measurement (0x2A37).
// Format: [flags] [hr_value] [rr_low] [rr_high] (optional)
func ParseLiveHR(data []byte) (hr int, rrInterval int, err error) {
	if len(data) < 2 {
		return 0, 0, fmt.Errorf("HR data too short")
	}
	hr = int(data[1] & 0xFF)
	if len(data) >= 4 {
		rrInterval = int(data[2]) | int(data[3])<<8
	} else {
		rrInterval = 1024 // default
	}
	return hr, rrInterval, nil
}

// BuildBondState sends bond state to watch.
func BuildBondState(bound bool) []byte {
	v := byte(0)
	if bound {
		v = 1
	}
	return BuildPacket(CmdBondState, []byte{4, v})
}

// BuildGetTodaySteps requests today's steps (ack, data comes on fee1).
func BuildGetTodaySteps() []byte {
	return BuildPacket(CmdTodaySteps, nil)
}

// BuildGetStepHistory requests step history.
// dayOffset: 0=today, 1=yesterday, 2=day before
func BuildGetStepHistory(dayOffset byte) []byte {
	return BuildPacket(CmdStepHistory, []byte{dayOffset})
}

// BuildGetTodayHR requests today's HR data.
func BuildGetTodayHR() []byte {
	return BuildPacket(CmdTodayHR, nil)
}

// BuildGetHRHistory requests HR history for all days.
func BuildGetHRHistory() []byte {
	return BuildPacket(CmdHRHistory, []byte{0})
}

// BuildGetSleep requests sleep data.
// dayOffset: 0=today, 1=yesterday, 2=day before
func BuildGetSleep(dayOffset byte) []byte {
	return BuildPacket(CmdSleepData, []byte{1, dayOffset})
}

// BuildSyncTime sends current time to the watch.
// Uses BIG-ENDIAN Unix timestamp (CONFIRMED from z1.java).
func BuildSyncTime(t time.Time) []byte {
	ts := make([]byte, 4)
	binary.BigEndian.PutUint32(ts, uint32(t.Unix()))
	payload := append(ts, 8) // 8 = day of week constant
	return BuildPacket(CmdTimeSync, payload)
}

// BuildSyncTimezone sends timezone offset.
func BuildSyncTimezone(offsetSeconds int) []byte {
	payload := make([]byte, 6)
	payload[0] = 7 // constant
	payload[1] = 0
	binary.LittleEndian.PutUint32(payload[2:6], uint32(offsetSeconds))
	return BuildPacket(CmdTimezone, payload)
}

// BuildDeviceVersion requests device version info.
func BuildDeviceVersion() []byte {
	return BuildPacket(CmdDeviceVersion, nil)
}

// BuildMetricSystem requests metric/imperial setting.
func BuildMetricSystem() []byte {
	return BuildPacket(CmdMetricSystem, nil)
}

// ParseStepHistory parses step history from cmd 0x33 response.
// Format: [day_type] [steps_3LE] [distance_3LE] [calories_3LE]
func ParseStepHistory(payload []byte) (*StepRecord, error) {
	if len(payload) < 10 {
		return nil, fmt.Errorf("step history too short: %d", len(payload))
	}
	return &StepRecord{
		Steps:    decodeUint24LE(payload[1:4]),
		Distance: decodeUint24LE(payload[4:7]),
		Calories: decodeUint24LE(payload[7:10]),
	}, nil
}

func decodeUint24LE(data []byte) uint32 {
	return uint32(data[0]) | uint32(data[1])<<8 | uint32(data[2])<<16
}
