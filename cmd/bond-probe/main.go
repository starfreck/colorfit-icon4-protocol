package main

import (
	"fmt"
	"time"
	"github.com/noise-watch-client/internal/ble"
	"github.com/noise-watch-client/internal/protocol"
)

func main() {
	client := ble.NewClient()
	if err := client.Connect("EB:82:96:7B:74:3B"); err != nil {
		panic(err)
	}
	defer client.Disconnect()
	client.EnableNotifications()

	fmt.Println("=== Full CRP Init Sequence ===")
	fmt.Println()

	// Step 1: Read protocol version from fee1
	fmt.Println("Step 1: Read protocol version from 0xfee1...")
	client.SendPacket([]byte{}) // trigger service discovery response
	time.Sleep(500 * time.Millisecond)

	// Step 2: Send SPP Initial Handshake: cmd 0xB9, payload 0x0E
	fmt.Println("Step 2: SPP Initial Handshake (0xB9 0x0E)...")
	pkt := protocol.BuildPacket(0xB9, []byte{0x0E})
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
collectResponse("init handshake", client, 2*time.Second)

	// Step 3: Reply App Protocol Query: cmd 0xBD, payload 0x16 0x00
	fmt.Println("Step 3: Reply App Protocol Query (0xBD 0x16 0x00)...")
	pkt = protocol.BuildPacket(0xBD, []byte{0x16, 0x00})
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("app query", client, 2*time.Second)

	// Step 4: Query function/device info: cmd 0x5A, payload 0x00
	fmt.Println("Step 4: Query device info (0x5A 0x00)...")
	pkt = protocol.BuildPacket(0x5A, []byte{0x00})
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("device info", client, 2*time.Second)

	// Step 5: BT address query: cmd 0xB9, payload 0x06
	fmt.Println("Step 5: BT address query (0xB9 0x06)...")
	pkt = protocol.BuildPacket(0xB9, []byte{0x06})
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("bt addr", client, 2*time.Second)

	// Step 6: Create bond with MAC
	fmt.Println("Step 6: Create bond (0x77 0x04 + MAC)...")
	macBytes := []byte{0xEB, 0x82, 0x96, 0x7B, 0x74, 0x3B}
	bondPayload := append([]byte{0x04}, macBytes...)
	pkt = protocol.BuildPacket(0x77, bondPayload)
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("createBond", client, 3*time.Second)

	// Step 7: Send bond state bonded
	fmt.Println("Step 7: Send BondState(true)...")
	pkt = protocol.BuildBondState(true)
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("bondState", client, 3*time.Second)

	// Step 8: Now try data commands
	fmt.Println()
	fmt.Println("=== Testing Data Commands ===")
	fmt.Println()

	fmt.Println("Step 8: Battery...")
	time.Sleep(300 * time.Millisecond)

	fmt.Println("Step 9: HR History (0xAB 0x00)...")
	pkt = protocol.BuildGetHRHistory()
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("HR history", client, 3*time.Second)

	fmt.Println("Step 10: Step History (0x33 0x01)...")
	pkt = protocol.BuildGetStepHistory(1)
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("step history", client, 3*time.Second)

	fmt.Println("Step 11: Today Steps (0x32)...")
	pkt = protocol.BuildPacket(0x32, nil)
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("today steps", client, 3*time.Second)

	fmt.Println("Step 12: Device Version (0x2E)...")
	pkt = protocol.BuildDeviceVersion()
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("device version", client, 3*time.Second)

	fmt.Println("Step 13: Metric System (0x2A)...")
	pkt = protocol.BuildMetricSystem()
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("metric", client, 3*time.Second)

	fmt.Println("Step 14: Time Sync...")
	pkt = protocol.BuildSyncTime(time.Now())
	fmt.Printf("  TX: %X\n", pkt)
	client.SendPacket(pkt)
	time.Sleep(500 * time.Millisecond)
	collectResponse("time sync", client, 3*time.Second)

	fmt.Println()
	fmt.Println("=== Listening for live data (10s) ===")
	collectResponse("live", client, 10*time.Second)
	fmt.Println("Done.")
}

func collectResponse(label string, client *ble.Client, timeout time.Duration) {
	deadline := time.After(timeout)
	for {
		select {
		case resp := <-client.NotifyChan():
			cmd, payload, err := protocol.ParsePacket(resp)
			if err == nil {
				fmt.Printf("  [%s] RX: cmd=0x%02X payload=%X\n", label, cmd, payload)
			} else {
				fmt.Printf("  [%s] RX: raw=%X\n", label, resp)
			}
			return
		case <-deadline:
			fmt.Printf("  [%s] (no response)\n", label)
			return
		}
	}
}
