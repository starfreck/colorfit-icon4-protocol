// ble-scan captures raw BLE advertising packets.
// This helps identify what a device broadcasts before connection.
//
// Usage:
//
//	ble-scan                  # Scan all BLE devices
//	ble-scan -filter noise    # Filter for NoiseFit devices
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
	"strings"

	"tinygo.org/x/bluetooth"
)

func main() {
	filter := flag.String("filter", "", "Filter by name substring")
	duration := flag.Int("duration", 30, "Scan duration in seconds")
	flag.Parse()

	adapter := bluetooth.DefaultAdapter
	if err := adapter.Enable(); err != nil {
		log.Fatalf("Enable BLE: %v", err)
	}

	fmt.Println("=== BLE Raw Advertising Scanner ===")
	fmt.Printf("Scanning for %d seconds...\n", *duration)
	fmt.Println("Press Ctrl+C to stop")
	fmt.Println()

	seen := make(map[string]bool)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	adapter.Scan(func(a *bluetooth.Adapter, d bluetooth.ScanResult) {
		addr := d.Address.String()
		name := d.LocalName()
		rssi := d.RSSI

		if seen[addr] {
			return
		}

		if *filter != "" {
			if name != "" && !stringsContains(strings.ToLower(name), strings.ToLower(*filter)) {
				if !stringsContains(strings.ToLower(addr), strings.ToLower(*filter)) {
					return
				}
			}
		}

		seen[addr] = true
		ts := time.Now().Format("15:04:05.000")

		if name == "" {
			name = "(unknown)"
		}

		fmt.Printf("[%s] %-20s  RSSI=%4d  Name=%s\n", ts, addr, rssi, name)

		// Print manufacturer data if present
		for _, mfg := range d.ManufacturerData() {
			fmt.Printf("           Manufacturer: CompanyID=0x%04X Data=%X\n", mfg.CompanyID, mfg.Data)
		}

		// Print service UUIDs
		uuids := d.ServiceUUIDs()
		if len(uuids) > 0 {
			fmt.Printf("           Services: ")
			for _, u := range uuids {
				fmt.Printf("%s ", u.String())
			}
			fmt.Println()
		}
	})

	select {
	case <-time.After(time.Duration(*duration) * time.Second):
	case <-sigCh:
	}

	adapter.StopScan()
	fmt.Printf("\n=== Scan Complete: %d unique devices found ===\n", len(seen))
}

func stringsContains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsImpl(s, substr))
}

func containsImpl(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
