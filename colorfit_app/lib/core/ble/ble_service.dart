import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../protocol/constants.dart';
import '../protocol/parser.dart';

class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  
  final _responsesController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get responses => _responsesController.stream;
  
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  
  bool get isConnected => _device?.isConnected ?? false;
  
  /// Connect to device by MAC address
  Future<void> connect(String macAddress) async {
    final device = BluetoothDevice.fromId(macAddress);
    _device = device;
    
    await device.connect();
    _connectionStateController.add(ConnectionState.connected);
    
    // Discover services
    final services = await device.discoverServices();
    
    // Find write characteristic
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.uuid.toString() == ProtocolConstants.writeCharUuid) {
          _writeChar = char;
        }
        if (char.uuid.toString() == ProtocolConstants.notifyCharUuid) {
          _notifyChar = char;
          await char.setNotifyValue(true);
          char.onValueReceived.listen((data) {
            _responsesController.add(data);
          });
        }
      }
    }
    
    if (_writeChar == null || _notifyChar == null) {
      throw Exception('Required characteristics not found');
    }
  }
  
  /// Disconnect from device
  Future<void> disconnect() async {
    await _device?.disconnect();
    _connectionStateController.add(ConnectionState.disconnected);
    _device = null;
    _writeChar = null;
    _notifyChar = null;
  }
  
  /// Send a packet
  Future<void> sendPacket(List<int> packet) async {
    if (_writeChar == null) throw Exception('Not connected');
    await _writeChar!.write(packet, withoutResponse: true);
  }
  
  /// Read battery level
  Future<int?> readBattery() async {
    if (_device == null) return null;
    
    final services = await _device!.discoverServices();
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.uuid.toString() == ProtocolConstants.batteryCharUuid) {
          final value = await char.read();
          return ProtocolParser.parseBattery(value);
        }
      }
    }
    return null;
  }
  
  /// Sync time to watch
  Future<void> syncTime() async {
    await sendPacket(ProtocolParser.buildTimeSync(DateTime.now()));
  }

  /// Initialize CRP protocol (must be called after connection)
  Future<void> initProtocol() async {
    // SPP Initial Handshake
    await sendPacket(ProtocolParser.buildPacket(0xB9, [0x0E]));
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Reply App Protocol Query
    await sendPacket(ProtocolParser.buildPacket(0xBD, [0x16, 0x00]));
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Query device info
    await sendPacket(ProtocolParser.buildPacket(0x5A, [0x00]));
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Send bond state
  Future<void> sendBondState() async {
    await sendPacket(ProtocolParser.buildBondState(true));
  }
  
  /// Request HR history
  Future<void> requestHRHistory() async {
    await sendPacket(ProtocolParser.buildGetHRHistory());
  }
  
  /// Request step history
  Future<void> requestStepHistory(int dayOffset) async {
    await sendPacket(ProtocolParser.buildGetStepHistory(dayOffset));
  }
  
  /// Dispose resources
  void dispose() {
    _responsesController.close();
    _connectionStateController.close();
  }
}

enum ConnectionState { connected, disconnected }
