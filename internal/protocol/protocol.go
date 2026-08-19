// Package protocol defines constants, UUIDs, and types for the ColorFit Icon 4
// smartwatch BLE protocol (CrRepa/Jieli CRP chipset).
//
// Status: CONFIRMED via live GATT enumeration + decompiled CrRepa protocol code.
package protocol

import (
	"encoding/binary"
	"fmt"
	"time"
)

// BLE GATT UUIDs — CONFIRMED via live enumeration from ColorFit Icon 4.
var (
	// Write characteristics (phone → watch)
	WriteCharUUID = "0000fee2-0000-1000-8000-00805f9b34fb" // Primary write (CONFIRMED)
	WriteCharAlt  = "0000fee5-0000-1000-8000-00805f9b34fb" // Alternate write

	// Notify characteristics (watch → phone)
	NotifyCharUUID = "0000fee3-0000-1000-8000-00805f9b34fb" // Main response (CONFIRMED)
	NotifyChar1    = "0000fee1-0000-1000-8000-00805f9b34fb" // Step data
	NotifyChar9    = "0000fee9-0000-1000-8000-00805f9b34fb" // Additional

	// Standard BLE characteristics
	StdBattLevelChar = "00002a19-0000-1000-8000-00805f9b34fb"
	StdHRMeasChar    = "00002a37-0000-1000-8000-00805f9b34fb"
	StdDeviceName    = "00002a00-0000-1000-8000-00805f9b34fb"
)

// CrRepa frame format — CONFIRMED from com.crrepa.f.f2.java.
const (
	FrameMagic1    byte = 0xFE
	FrameMagic2    byte = 0xEA
	FrameLenMTU20  byte = 0x10
	FrameLenNormal byte = 0x20
	FrameHeaderLen      = 5
)

// Command types — CONFIRMED from CrRepa protocol.
const (
	CmdTodaySteps    byte = 0x32
	CmdStepHistory   byte = 0x33
	CmdTodayHR       byte = 0x37
	CmdSleepData     byte = 0xBC
	CmdStepDetail    byte = 0xB2
	CmdHRHistory     byte = 0xAB
	CmdTimeSync      byte = 0x31
	CmdDeviceVersion byte = 0x2E
	CmdMetricSystem  byte = 0x2A
	CmdBondState     byte = 0x81
	CmdCreateBond    byte = 0x77
	CmdRemoveBond    byte = 0xF8
)

// HeartRateRecord represents a single HR measurement with timestamp.
type HeartRateRecord struct {
	Timestamp time.Time
	BPM       int
}

// StepRecord represents daily step summary.
type StepRecord struct {
	Timestamp time.Time
	Steps     int
	Calories  int
	Distance  int
}

// SleepRecord represents a sleep segment.
type SleepRecord struct {
	Timestamp time.Time
	Stage     byte
	Duration  int
}

// DeviceInfo holds watch information.
type DeviceInfo struct {
	BatteryPct int
	Metric     bool
}

// BuildPacket creates a CrRepa protocol packet.
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

// ParsePacket parses a CrRepa response, returns cmd and payload.
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
// Format: [sub_type=0] [packet_index] [HR byte, TS LE32] ...
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

// BuildBondState sends bond state to watch.
func BuildBondState(bound bool) []byte {
	v := byte(0)
	if bound {
		v = 1
	}
	return BuildPacket(CmdBondState, []byte{4, v})
}

// BuildGetTodaySteps requests today's steps.
func BuildGetTodaySteps() []byte {
	return BuildPacket(CmdTodaySteps, nil)
}

// BuildGetTodayHR requests today's heart rate data.
func BuildGetTodayHR() []byte {
	return BuildPacket(CmdTodayHR, nil)
}

// BuildGetHRHistory requests HR history for all days.
func BuildGetHRHistory() []byte {
	return BuildPacket(CmdHRHistory, []byte{0})
}

// BuildGetStepDetail requests step detail for a day (0=today, 1=yesterday...).
func BuildGetStepDetail(day byte) []byte {
	return BuildPacket(CmdStepDetail, []byte{1, day})
}

// BuildGetSleep requests sleep data for a day.
func BuildGetSleep(day byte) []byte {
	return BuildPacket(CmdSleepData, []byte{1, day})
}

// BuildSyncTime sends current time to the watch.
func BuildSyncTime(t time.Time) []byte {
	return BuildPacket(CmdTimeSync, []byte{
		byte(t.Year() - 2000), byte(t.Month()), byte(t.Day()),
		byte(t.Hour()), byte(t.Minute()), byte(t.Second()), 8,
	})
}

// BuildDeviceVersion requests device version info.
func BuildDeviceVersion() []byte {
	return BuildPacket(CmdDeviceVersion, nil)
}

// BuildMetricSystem requests metric/imperial setting.
func BuildMetricSystem() []byte {
	return BuildPacket(CmdMetricSystem, nil)
}
