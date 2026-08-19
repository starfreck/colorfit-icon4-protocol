import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../protocol/constants.dart';
import '../protocol/parser.dart';
import '../storage/data_storage.dart';
import '../../data/models/health_data.dart';

enum ConnectionState { connected, disconnected, connecting, disconnecting }

class BluetoothService {
  final DataStorage _storage = DataStorage();
  
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  
  final _dataController = StreamController<HealthData>.broadcast();
  Stream<HealthData> get dataStream => _dataController.stream;
  
  HealthData _currentData = const HealthData();
  HealthData get currentData => _currentData;
  
  bool get isConnected => _device?.isConnected ?? false;
  bool get isReady => isConnected && _writeChar != null && _notifyChar != null;
  
  // Check and request permissions
  Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    return statuses.values.every((status) => status.isGranted);
  }
  
  // Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }
  
  // Enable Bluetooth
  Future<bool> enableBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Disable Bluetooth
  Future<bool> disableBluetooth() async {
    try {
      // Note: turnOff is deprecated in Android SDK 33
      // For Android 13+, user needs to manually disable Bluetooth
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Scan for devices
  Stream<List<ScanResult>> scanForDevices({Duration timeout = const Duration(seconds: 10)}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }
  
  // Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
  
  // Connect to device
  Future<void> connect(String address) async {
    final device = BluetoothDevice.fromId(address);
    _device = device;
    
    _connectionStateController.add(ConnectionState.connecting);
    
    await device.connect();
    
    // Discover services
    final services = await device.discoverServices();
    debugPrint('Discovered ${services.length} services');
    
    // Find characteristics
    for (final service in services) {
      debugPrint('Service: ${service.uuid}');
      for (final char in service.characteristics) {
        debugPrint('  Char: ${char.uuid} props: ${char.properties}');
        final uuidStr = char.uuid.toString().toLowerCase();
        
        if (uuidStr == ProtocolConstants.writeCharUuid ||
            uuidStr == ProtocolConstants.writeCharAltUuid) {
          if (_writeChar == null) {
            _writeChar = char;
            debugPrint('  -> Write char: $uuidStr');
          }
        }
        if (uuidStr == ProtocolConstants.notifyCharUuid) {
          _notifyChar = char;
          await char.setNotifyValue(true);
          char.onValueReceived.listen((data) {
            _handleResponse(data);
          });
          debugPrint('  -> Notify char: $uuidStr');
        }
      }
    }
    
    if (_writeChar == null || _notifyChar == null) {
      debugPrint('Write char: ${_writeChar?.uuid}, Notify char: ${_notifyChar?.uuid}');
      await device.disconnect();
      _connectionStateController.add(ConnectionState.disconnected);
      throw Exception('Required characteristics not found');
    }
    
    // Save device address
    await _storage.setDeviceAddress(address);
    
    // Now we're truly connected
    _connectionStateController.add(ConnectionState.connected);
    
    // Initialize CRP protocol
    await _initProtocol();
  }
  
  // Initialize CRP protocol
  Future<void> _initProtocol() async {
    debugPrint('CRP: Starting init sequence');
    
    // SPP Initial Handshake
    await sendPacket(ProtocolParser.buildPacket(0xB9, [0x0E]));
    debugPrint('CRP: Sent handshake 0xB9 0x0E');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Reply App Protocol Query
    await sendPacket(ProtocolParser.buildPacket(0xBD, [0x16, 0x00]));
    debugPrint('CRP: Sent app query 0xBD 0x16 0x00');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Query device info
    await sendPacket(ProtocolParser.buildPacket(0x5A, [0x00]));
    debugPrint('CRP: Sent device info query 0x5A 0x00');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Sync time
    await sendPacket(ProtocolParser.buildTimeSync(DateTime.now()));
    debugPrint('CRP: Synced time');
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Sync timezone
    await sendPacket(ProtocolParser.buildTimezoneSync(DateTime.now()));
    debugPrint('CRP: Synced timezone');
    await Future.delayed(const Duration(milliseconds: 500));
    
    debugPrint('CRP: Init sequence complete');
  }
  
  // Send a packet
  Future<void> sendPacket(List<int> packet) async {
    if (_writeChar == null) throw Exception('Not connected');
    debugPrint('TX: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    await _writeChar!.write(packet, withoutResponse: true);
  }
  
  // Handle response
  void _handleResponse(List<int> data) {
    debugPrint('RX: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    
    final parsed = ProtocolParser.parsePacket(data);
    if (parsed == null) {
      debugPrint('RX: Failed to parse');
      return;
    }
    
    final cmd = parsed.cmd;
    final payload = parsed.payload;
    debugPrint('RX: cmd=0x${cmd.toRadixString(16)} payload=${payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    
    // Update current data based on command
    switch (cmd) {
      case 0x2A19: // Battery
        if (payload.isNotEmpty) {
          _currentData = _currentData.copyWith(batteryLevel: payload[0]);
        }
        break;
      case 0xAB: // HR History
        final records = ProtocolParser.parseHRHistory(payload);
        if (records != null) {
          _currentData = _currentData.copyWith(
            heartRateHistory: records.map((r) => HeartRateRecord(
              timestamp: r.timestamp,
              bpm: r.bpm,
            )).toList(),
          );
          for (final record in records) {
            _storage.saveHeartRate(record.bpm, record.timestamp);
          }
        }
        break;
      case 0x33: // Step History
        final record = ProtocolParser.parseStepHistory(payload);
        if (record != null) {
          _currentData = _currentData.copyWith(
            steps: record.steps,
            distanceKm: record.distanceKm,
            calories: record.calories,
          );
          // Save to storage
          _storage.saveSteps(record.steps, DateTime.now());
          _storage.saveDistance(record.distanceKm, DateTime.now());
          _storage.saveCalories(record.calories, DateTime.now());
        }
        break;
      case 0x2A37: // Live HR
        final hr = ProtocolParser.parseLiveHR(payload);
        if (hr != null) {
          _currentData = _currentData.copyWith(currentBPM: hr.bpm);
        }
        break;
    }
    
    _dataController.add(_currentData);
  }
  
  // Request HR history
  Future<void> requestHRHistory() async {
    await sendPacket(ProtocolParser.buildGetHRHistory());
  }
  
  // Request step history
  Future<void> requestStepHistory(int dayOffset) async {
    await sendPacket(ProtocolParser.buildGetStepHistory(dayOffset));
  }
  
  // Read battery
  Future<void> readBattery() async {
    if (_device == null) return;
    
    final services = await _device!.discoverServices();
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.uuid.toString().toLowerCase() == ProtocolConstants.batteryCharUuid) {
          final value = await char.read();
          if (value.isNotEmpty) {
            _currentData = _currentData.copyWith(batteryLevel: value[0]);
            _dataController.add(_currentData);
          }
        }
      }
    }
  }
  
  // Sync time
  Future<void> syncTime() async {
    await sendPacket(ProtocolParser.buildTimeSync(DateTime.now()));
  }
  
  // Disconnect
  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }
    _connectionStateController.add(ConnectionState.disconnected);
    _device = null;
    _writeChar = null;
    _notifyChar = null;
  }
  
  // Dispose
  void dispose() {
    _connectionStateController.close();
    _dataController.close();
  }
}
