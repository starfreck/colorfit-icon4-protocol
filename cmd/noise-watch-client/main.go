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

	if err := client.EnableNotifications(); err != nil {
		log.Fatalf("Notifications: %v", err)
	}

	fmt.Println("Connected! Reading sensor data...")
	fmt.Println()

	// Read battery
	readBattery(client)

	// Sync time
	syncTime(client)

	// Send bond state
	fmt.Println("Sending bond state...")
	client.SendPacket(protocol.BuildBondState(true))
	time.Sleep(500 * time.Millisecond)

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
	// Check if it's a standard HR notification (0x2A37)
	if len(data) >= 2 {
		// Try CrRePa parse first
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
			case 0x33: // Step History
				record, err := protocol.ParseStepHistory(payload)
				if err == nil {
					fmt.Printf("  Steps: %d | Distance: %.1f km | Calories: %d\n",
						record.Steps, float64(record.Distance)/1000, record.Calories)
					return
				}
			case 0x32: // Steps ack
				fmt.Printf("  Steps command acknowledged\n")
				return
			case 0x81: // Bond state
				fmt.Printf("  Bond state: %x\n", payload)
				return
			case 0x2E: // Device version
				fmt.Printf("  Device version: %x\n", payload)
				return
			case 0x2A: // Metric
				metric := "metric"
				if len(payload) > 0 && payload[0] != 0 {
					metric = "imperial"
				}
				fmt.Printf("  Unit system: %s\n", metric)
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
	fmt.Printf("  [Unknown] %x\n", data)
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
