// noise-watch-client connects to a ColorFit smartwatch over BLE
// and prints live sensor data to stdout.
//
// Usage:
//
//	noise-watch-client                          # scan and connect
//	noise-watch-client -addr XX:XX:XX:XX:XX:XX # connect directly
//	noise-watch-client -enumerate               # list GATT services
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
	fmt.Println("Protocol: CrRepa (Jieli CRP chipset)")
	fmt.Println()

	client := ble.NewClient()

	if *addr == "" {
		fmt.Println("Usage: noise-watch-client -addr XX:XX:XX:XX:XX:XX")
		fmt.Println()
		fmt.Println("Available BLE devices nearby:")
		fmt.Println("  Use 'bluetoothctl scan on' to find your watch MAC address")
		os.Exit(1)
	}

	if err := client.Connect(*addr); err != nil {
		log.Fatalf("Connection failed: %v", err)
	}
	defer client.Disconnect()

	if *enumerate {
		fmt.Println("Enumeration complete.")
		return
	}

	if err := client.EnableNotifications(); err != nil {
		log.Fatalf("Notifications: %v", err)
	}

	fmt.Println("Connected! Reading sensor data...")
	fmt.Println()

	// Read battery from standard BLE service
	readBattery(client)

	// Send bond state
	fmt.Println("Sending bond state...")
	if err := client.SendPacket(protocol.BuildBondState(true)); err != nil {
		fmt.Printf("  Error: %v\n", err)
	}
	time.Sleep(500 * time.Millisecond)

	// Get HR history
	fmt.Println("Requesting heart rate history...")
	if err := client.SendPacket(protocol.BuildGetHRHistory()); err != nil {
		fmt.Printf("  Error: %v\n", err)
	}
	time.Sleep(500 * time.Millisecond)

	// Collect responses for 5 seconds
	deadline := time.After(5 * time.Second)
	for {
		select {
		case resp := <-client.NotifyChan():
			cmd, payload, err := protocol.ParsePacket(resp)
			if err != nil {
				fmt.Printf("  Parse error: %v\n", err)
				continue
			}
			fmt.Printf("  Response cmd=0x%02X payload=%d bytes\n", cmd, len(payload))

			if cmd == 0xAB && len(payload) > 2 && payload[0] == 0 {
				records, err := protocol.ParseHRHistory(payload)
				if err != nil {
					fmt.Printf("  HR parse error: %v\n", err)
				} else {
					fmt.Printf("  Heart Rate History (%d readings):\n", len(records))
					for _, r := range records {
						fmt.Printf("    %s: %d BPM\n", r.Timestamp.Format("2006-01-02 15:04"), r.BPM)
					}
				}
			} else if cmd == 0x2E {
				fmt.Printf("  Device Version: %x\n", payload)
			} else if cmd == 0x2A {
				metric := "metric"
				if len(payload) > 0 && payload[0] != 0 {
					metric = "imperial"
				}
				fmt.Printf("  Unit system: %s\n", metric)
			} else {
				fmt.Printf("  Raw: %x\n", payload)
			}
		case <-deadline:
			goto done
		}
	}
done:

	// Listen for unsolicited notifications
	fmt.Println()
	fmt.Println("Listening for live data (Ctrl+C to quit)...")
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	for {
		select {
		case resp := <-client.NotifyChan():
			cmd, payload, err := protocol.ParsePacket(resp)
			if err != nil {
				continue
			}
			fmt.Printf("[0x%02X] %x\n", cmd, payload)
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
	battUUID := mustParseUUID("00002a19-0000-1000-8000-00805f9b34fb")
	for _, svc := range services {
		chars, _ := svc.DiscoverCharacteristics([]bluetooth.UUID{})
		for _, ch := range chars {
			if ch.UUID() == battUUID {
				buf := make([]byte, 16)
				n, err := ch.Read(buf)
				if err == nil && n > 0 {
					fmt.Printf("Battery: %d%%\n", buf[0])
				}
				return
			}
		}
	}
}

func mustParseUUID(s string) bluetooth.UUID {
	u, _ := bluetooth.ParseUUID(s)
	return u
}
