// Package ble provides a BLE client for ColorFit watches using the CrRepa protocol.
package ble

import (
	"fmt"
	"log"
	"time"

	"tinygo.org/x/bluetooth"
)

// Client wraps a BLE connection to a ColorFit watch.
type Client struct {
	adapter    *bluetooth.Adapter
	device     bluetooth.Device
	writeChar  bluetooth.DeviceCharacteristic
	notifyChar bluetooth.DeviceCharacteristic
	notifyCh   chan []byte
}

// NewClient creates a new BLE client.
func NewClient() *Client {
	return &Client{notifyCh: make(chan []byte, 64)}
}

// Connect directly to a watch by BLE MAC address.
func (c *Client) Connect(addr string) error {
	c.adapter = bluetooth.DefaultAdapter
	if err := c.adapter.Enable(); err != nil {
		return fmt.Errorf("enable adapter: %w", err)
	}

	mac, err := bluetooth.ParseMAC(addr)
	if err != nil {
		return fmt.Errorf("invalid address: %w", err)
	}

	log.Printf("Connecting to %s...", addr)
	c.device, err = c.adapter.Connect(bluetooth.Address{
		MACAddress: bluetooth.MACAddress{MAC: mac},
	}, bluetooth.ConnectionParams{})
	if err != nil {
		return fmt.Errorf("connect failed: %w", err)
	}

	return c.discover()
}

func (c *Client) discover() error {
	services, err := c.device.DiscoverServices([]bluetooth.UUID{})
	if err != nil {
		return fmt.Errorf("discover services: %w", err)
	}

	log.Printf("Discovered %d services", len(services))

	fee2UUID := mustParseUUID("0000fee2-0000-1000-8000-00805f9b34fb")
	fee3UUID := mustParseUUID("0000fee3-0000-1000-8000-00805f9b34fb")
	fee5UUID := mustParseUUID("0000fee5-0000-1000-8000-00805f9b34fb")

	for _, svc := range services {
		chars, err := svc.DiscoverCharacteristics([]bluetooth.UUID{})
		if err != nil {
			continue
		}
		for _, ch := range chars {
			uuid := ch.UUID()
			if uuid == fee2UUID && (c.writeChar.UUID() == bluetooth.UUID{}) {
				c.writeChar = ch
				log.Printf("  Write char: fee2")
			}
			if uuid == fee3UUID {
				c.notifyChar = ch
				log.Printf("  Notify char: fee3")
			}
			if uuid == fee5UUID && (c.writeChar.UUID() == bluetooth.UUID{}) {
				c.writeChar = ch
				log.Printf("  Write char (alt): fee5")
			}
		}
	}

	if c.writeChar.UUID() == (bluetooth.UUID{}) {
		return fmt.Errorf("write characteristic not found")
	}
	return nil
}

// EnableNotifications subscribes to the notify characteristic.
func (c *Client) EnableNotifications() error {
	err := c.notifyChar.EnableNotifications(func(buf []byte) {
		data := make([]byte, len(buf))
		copy(data, buf)
		select {
		case c.notifyCh <- data:
		default:
		}
	})
	if err != nil {
		return fmt.Errorf("enable notifications: %w", err)
	}
	log.Printf("Notifications enabled")
	return nil
}

// SendPacket sends a raw CrRepa packet.
func (c *Client) SendPacket(pkt []byte) error {
	_, err := c.writeChar.WriteWithoutResponse(pkt)
	return err
}

// ReadResponse reads the next notification with timeout.
func (c *Client) ReadResponse(timeout time.Duration) ([]byte, error) {
	select {
	case data := <-c.notifyCh:
		return data, nil
	case <-time.After(timeout):
		return nil, fmt.Errorf("timeout")
	}
}

// Device returns the underlying BLE device.
func (c *Client) Device() bluetooth.Device {
	return c.device
}

// NotifyChan returns the notification channel.
func (c *Client) NotifyChan() <-chan []byte {
	return c.notifyCh
}

// Disconnect closes the BLE connection.
func (c *Client) Disconnect() error {
	return c.device.Disconnect()
}

func mustParseUUID(s string) bluetooth.UUID {
	u, _ := bluetooth.ParseUUID(s)
	return u
}
