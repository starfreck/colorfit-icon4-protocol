package main

import (
	"fmt"
	"time"
	"github.com/noise-watch-client/internal/ble"
	"github.com/noise-watch-client/internal/protocol"
	"tinygo.org/x/bluetooth"
)

func main() {
	client := ble.NewClient()
	if err := client.Connect("EB:82:96:7B:74:3B"); err != nil {
		panic(err)
	}
	defer client.Disconnect()
	client.EnableNotifications()

	// Init
	client.SendPacket(protocol.BuildPacket(0xB9, []byte{0x0E}))
	time.Sleep(300 * time.Millisecond)
	client.SendPacket(protocol.BuildPacket(0xBD, []byte{0x16, 0x00}))
	time.Sleep(300 * time.Millisecond)
	client.SendPacket(protocol.BuildPacket(0x5A, []byte{0x00}))
	time.Sleep(300 * time.Millisecond)
	Drain(client)

	// Battery
	fmt.Println("=== Battery ===")
	services, _ := client.Device().DiscoverServices([]bluetooth.UUID{})
	for _, svc := range services {
		chars, _ := svc.DiscoverCharacteristics([]bluetooth.UUID{})
		for _, ch := range chars {
			if ch.UUID().String() == "00002a19-0000-1000-8000-00805f9b34fb" {
				buf := make([]byte, 16)
				if n, err := ch.Read(buf); err == nil && n > 0 {
					fmt.Printf("  Battery: %d%%\n", buf[0])
				}
			}
		}
	}

	// Bond
	fmt.Println("\n=== Bond ===")
	client.SendPacket(protocol.BuildBondState(true))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// Time sync
	fmt.Println("\n=== Time Sync ===")
	client.SendPacket(protocol.BuildSyncTime(time.Now()))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// HR History
	fmt.Println("\n=== HR History ===")
	client.SendPacket(protocol.BuildPacket(0xAB, []byte{0x00}))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// Step History (today=0, yesterday=1, day before=2)
	for _, d := range []byte{0, 1, 2} {
		fmt.Printf("\n=== Step History (day=%d) ===\n", d)
		client.SendPacket(protocol.BuildPacket(0x33, []byte{d}))
		time.Sleep(500 * time.Millisecond)
		Drain(client)
	}

	// Today steps
	fmt.Println("\n=== Today Steps ===")
	client.SendPacket(protocol.BuildPacket(0x32, nil))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// HR today
	fmt.Println("\n=== HR Today ===")
	client.SendPacket(protocol.BuildPacket(0x37, nil))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// Sleep
	fmt.Println("\n=== Sleep (day=1) ===")
	client.SendPacket(protocol.BuildPacket(0xBC, []byte{0x01, 0x01}))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// Device version
	fmt.Println("\n=== Device Version ===")
	client.SendPacket(protocol.BuildPacket(0x2E, nil))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// Metric
	fmt.Println("\n=== Metric ===")
	client.SendPacket(protocol.BuildPacket(0x2A, nil))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// Timezone
	fmt.Println("\n=== Timezone ===")
	client.SendPacket(protocol.BuildSyncTimezone(19800))
	time.Sleep(500 * time.Millisecond)
	Drain(client)

	// Listen for live HR 10s
	fmt.Println("\n=== Live HR (10s) ===")
	deadline := time.After(10 * time.Second)
	for {
		select {
		case resp := <-client.NotifyChan():
			cmd, payload, err := protocol.ParsePacket(resp)
			if err == nil {
				fmt.Printf("  RX: cmd=0x%02X payload=%X\n", cmd, payload)
			} else {
				fmt.Printf("  RX raw=%X\n", resp)
			}
		case <-deadline:
			fmt.Println("Done.")
			return
		}
	}
}

func Drain(client *ble.Client) {
	for {
		select {
		case resp := <-client.NotifyChan():
			cmd, payload, err := protocol.ParsePacket(resp)
			if err == nil {
				fmt.Printf("  RX: cmd=0x%02X payload=%X\n", cmd, payload)
			} else {
				fmt.Printf("  RX: raw=%X\n", resp)
			}
		default:
			return
		}
	}
}
