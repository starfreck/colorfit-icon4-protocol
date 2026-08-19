// noise-watch-client connects to a ColorFit smartwatch over BLE
// and prints live sensor data to stdout.
//
// Usage:
//
//	noise-watch-client -addr XX:XX:XX:XX:XX:XX
//	noise-watch-client -addr XX:XX:XX:XX:XX:XX -enumerate
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/noise-watch-client/internal/ble"
	"github.com/noise-watch-client/internal/protocol"
	"tinygo.org/x/bluetooth"
)

func main() {
	addr := flag.String("addr", "", "BLE MAC address (e.g. XX:XX:XX:XX:XX:XX)")
	enumerate := flag.Bool("enumerate", false, "List GATT services and exit")
	otaCapture := flag.Bool("ota", false, "Capture OTA traffic to ota_capture.log")
	flag.Parse()

	log.SetFlags(0)
	log.SetOutput(os.Stdout)

	fmt.Println("=== Noise ColorFit Watch Client ===")
	fmt.Println("Protocol: CrRePa (Jieli CRP chipset)")
	fmt.Println()

	client := ble.NewClient()

	if *addr == "" {
		fmt.Println("Usage: noise-watch-client -addr XX:XX:XX:XX:XX:XX")
		fmt.Println()
		fmt.Println("Find your watch MAC:")
		fmt.Println("  bluetoothctl scan on")
		fmt.Println("  bluetoothctl devices")
		os.Exit(1)
	}

	if err := client.Connect(*addr); err != nil {
		log.Fatalf("Connection failed: %v", err)
	}
	defer client.Disconnect()

	if *enumerate {
		enumerateServices(client)
		return
	}

	if *otaCapture {
		captureOTATraffic(client)
		return
	}

	if err := client.EnableNotifications(); err != nil {
		log.Fatalf("Notifications: %v", err)
	}

	fmt.Println("Connected! Initializing CRP protocol...")
	fmt.Println()

	// CRP Init Sequence (from decompiled NoiseFit APK)
	// Step 1: SPP Initial Handshake
	fmt.Println("Sending SPP handshake...")
	client.SendPacket(protocol.BuildPacket(0xB9, []byte{0x0E}))
	time.Sleep(500 * time.Millisecond)
	collectResponses(client, 1*time.Second)

	// Step 2: Reply App Protocol Query
	fmt.Println("Sending app protocol query...")
	client.SendPacket(protocol.BuildPacket(0xBD, []byte{0x16, 0x00}))
	time.Sleep(500 * time.Millisecond)
	collectResponses(client, 1*time.Second)

	// Step 3: Query device info
	fmt.Println("Querying device info...")
	client.SendPacket(protocol.BuildPacket(0x5A, []byte{0x00}))
	time.Sleep(500 * time.Millisecond)
	collectResponses(client, 1*time.Second)

	// Read battery
	readBattery(client)

	// Sync time
	syncTime(client)

	// Send bond state
	fmt.Println("Sending bond state...")
	client.SendPacket(protocol.BuildBondState(true))
	time.Sleep(500 * time.Millisecond)
	collectResponses(client, 1*time.Second)

	// Get HR history
	fmt.Println("\nHeart Rate History:")
	client.SendPacket(protocol.BuildGetHRHistory())
	time.Sleep(500 * time.Millisecond)
	collectResponses(client, 5*time.Second)

	// Get step history
	fmt.Println("\nStep History:")
	client.SendPacket(protocol.BuildGetStepHistory(1)) // yesterday
	time.Sleep(500 * time.Millisecond)
	collectResponses(client, 3*time.Second)

	// Listen for live data
	fmt.Println("\nListening for live data (Ctrl+C to quit)...")
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	for {
		select {
		case resp := <-client.NotifyChan():
			handleResponse(resp)
		case <-sigCh:
			fmt.Println("\nDisconnecting...")
			return
		}
	}
}

func readBattery(client *ble.Client) {
	services, err := client.Device().DiscoverServices([]bluetooth.UUID{})
	if err != nil {
		return
	}
	for _, svc := range services {
		chars, _ := svc.DiscoverCharacteristics([]bluetooth.UUID{})
		for _, ch := range chars {
			if ch.UUID().String() == "00002a19-0000-1000-8000-00805f9b34fb" {
				buf := make([]byte, 16)
				if n, err := ch.Read(buf); err == nil && n > 0 {
					fmt.Printf("Battery: %d%%\n", buf[0])
				}
				return
			}
		}
	}
}

func syncTime(client *ble.Client) {
	fmt.Println("Syncing time...")
	client.SendPacket(protocol.BuildSyncTime(time.Now()))
	time.Sleep(300 * time.Millisecond)
}

func collectResponses(client *ble.Client, d time.Duration) {
	deadline := time.After(d)
	for {
		select {
		case resp := <-client.NotifyChan():
			handleResponse(resp)
		case <-deadline:
			return
		}
	}
}

func handleResponse(data []byte) {
	// Try CrRePa parse first
	if len(data) >= 5 && data[0] == 0xFE && data[1] == 0xEA {
		cmd, payload, err := protocol.ParsePacket(data)
		if err == nil {
			switch cmd {
			case 0xAB: // HR History
				records, err := protocol.ParseHRHistory(payload)
				if err == nil {
					for _, r := range records {
						fmt.Printf("  %s: %d BPM\n",
							r.Timestamp.Format("2006-01-02 15:04"), r.BPM)
					}
					return
				}
				fmt.Printf("  HR History: %X\n", payload)
				return
			case 0x33: // Step History
				record, err := protocol.ParseStepHistory(payload)
				if err == nil {
					fmt.Printf("  Steps: %d | Distance: %.1f km | Calories: %d\n",
						record.Steps, float64(record.Distance)/1000, record.Calories)
					return
				}
				fmt.Printf("  Step History: %X\n", payload)
				return
			case 0x32: // Steps ack
				fmt.Printf("  Steps acknowledged (payload=%X)\n", payload)
				return
			case 0x81: // Bond state
				fmt.Printf("  Bond state: %X\n", payload)
				return
			case 0x2E: // Device version
				fmt.Printf("  Device version: %X\n", payload)
				return
			case 0x2A: // Metric
				metric := "metric"
				if len(payload) > 0 && payload[0] != 0 {
					metric = "imperial"
				}
				fmt.Printf("  Unit system: %s\n", metric)
				return
			case 0x5A: // Device info
				// Parse as ASCII string
				str := ""
				for _, b := range payload[1:] {
					if b >= 0x20 && b < 0x7F {
						str += string(b)
					}
				}
				if str != "" {
					fmt.Printf("  Device info: %s (raw=%X)\n", str, payload)
				} else {
					fmt.Printf("  Device info: %X\n", payload)
				}
				return
			default:
				fmt.Printf("  [cmd=0x%02X] %X\n", cmd, payload)
				return
			}
		}
	}

	// Check for standard HR measurement (0x2A37)
	if len(data) == 2 {
		hr, _, err := protocol.ParseLiveHR(data)
		if err == nil && hr > 0 && hr < 255 {
			fmt.Printf("  [Live HR] %d BPM\n", hr)
			return
		}
	}

	// Unknown
	fmt.Printf("  [Unknown] %X\n", data)
}

func captureOTATraffic(client *ble.Client) {
	fmt.Println("=== OTA Traffic Capture Mode ===")
	fmt.Println("Watching for OTA packets on service 0xAE00...")
	fmt.Println("Start a firmware update from the NoiseFit app to capture traffic.")
	fmt.Println("Press Ctrl+C to stop and save capture.")
	fmt.Println()

	// Open capture file
	f, err := os.Create("ota_capture.log")
	if err != nil {
		log.Fatalf("Create capture file: %v", err)
	}
	defer f.Close()

	// Write header
	fmt.Fprintf(f, "# OTA Capture Log\n")
	fmt.Fprintf(f, "# Started: %s\n", time.Now().Format(time.RFC3339))
	fmt.Fprintf(f, "# Format: [TIMESTAMP] [DIRECTION] [OPCODE] [HEX_DATA]\n")
	fmt.Fprintf(f, "#\n")

	// Try to subscribe to OTA notify characteristic
	fmt.Println("Subscribing to OTA notifications (0xAE02)...")
	// Note: This requires the OTA service to exist on the watch
	// The watch may not expose this service until an OTA update is initiated

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	packetCount := 0
	fmt.Println("Waiting for OTA packets...")

	for {
		select {
		case resp := <-client.NotifyChan():
			packetCount++
			ts := time.Now().Format("2006-01-02 15:04:05.000")

			// Try to parse as OTA packet
			if len(resp) >= 3 && resp[0] == protocol.OTAStartTag {
				opcode, payload, err := protocol.ParseOTAPacket(resp)
				if err == nil {
					fmt.Printf("[%s] [RX] OTA opcode=0x%02X len=%d\n", ts, opcode, len(payload))
					fmt.Fprintf(f, "%s RX 0x%02X %X\n", ts, opcode, resp)
				} else {
					fmt.Printf("[%s] [RX] Raw: %X\n", ts, resp)
					fmt.Fprintf(f, "%s RX 0x?? %X\n", ts, resp)
				}
			} else {
				// Might be CrRePa response to OTA command
				cmd, payload, err := protocol.ParsePacket(resp)
				if err == nil {
					fmt.Printf("[%s] [RX] CrRePa cmd=0x%02X len=%d\n", ts, cmd, len(payload))
					fmt.Fprintf(f, "%s RX CrRePa:0x%02X %X\n", ts, cmd, resp)
				} else {
					fmt.Printf("[%s] [RX] Raw: %X\n", ts, resp)
					fmt.Fprintf(f, "%s RX raw %X\n", ts, resp)
				}
			}

		case <-sigCh:
			fmt.Printf("\nCapture stopped. %d packets captured.\n", packetCount)
			fmt.Fprintf(f, "#\n# Stopped: %s\n# Total packets: %d\n", time.Now().Format(time.RFC3339), packetCount)
			fmt.Println("Saved to ota_capture.log")
			return
		}
	}
}

func enumerateServices(client *ble.Client) {
	services, err := client.Device().DiscoverServices([]bluetooth.UUID{})
	if err != nil {
		log.Fatalf("Discover: %v", err)
	}

	fmt.Printf("Discovered %d services:\n\n", len(services))
	for _, svc := range services {
		fmt.Printf("Service: %s\n", svc.UUID().String())
		chars, _ := svc.DiscoverCharacteristics([]bluetooth.UUID{})
		for _, ch := range chars {
			fmt.Printf("  Char: %s\n", ch.UUID().String())
			buf := make([]byte, 512)
			if n, err := ch.Read(buf); err == nil && n > 0 {
				fmt.Printf("    Read (%d bytes): %x\n", n, buf[:n])
			}
		}
		fmt.Println()
	}
}
