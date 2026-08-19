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
  
  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isTransferringWatchFace = false;
  bool get isTransferringWatchFace => _isTransferringWatchFace;

  bool get isConnected => _device?.isConnected ?? false;
  bool get isReady => isConnected && _writeChar != null && _notifyChar != null;

  String? get currentDeviceAddress => _device?.remoteId.str ?? _storage.getDeviceAddress();
  String? get currentDeviceName =>
      _device?.platformName.isNotEmpty == true ? _device!.platformName : _storage.getDeviceName();

  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;

  void init() {
    _adapterStateSub?.cancel();
    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        tryAutoConnect();
      }
    });
  }

  Future<bool> tryAutoConnect() async {
    final savedAddress = _storage.getDeviceAddress();
    if (savedAddress != null && savedAddress.isNotEmpty && !isConnected && !_isConnecting) {
      try {
        debugPrint('Auto-connecting to saved device: $savedAddress');
        await connect(savedAddress, isAuto: true);
        return isConnected;
      } catch (e) {
        debugPrint('Auto-connect failed: $e');
        return false;
      }
    }
    return false;
  }
  
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
  Future<void> connect(String address, {bool isAuto = false}) async {
    final device = BluetoothDevice.fromId(address);
    _device = device;
    
    _connectionStateController.add(ConnectionState.connecting);
    
    await device.connect();
    
    // Request MTU negotiation
    try {
      final mtu = await device.requestMtu(256);
      debugPrint('CRP: Negotiated GATT MTU = $mtu');
    } catch (e) {
      debugPrint('CRP: MTU request error: $e');
    }
    
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
    if (_isTransferringWatchFace && !_isWatchFacePacket(packet)) {
      debugPrint('CRP: Suppressed background packet during transfer: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return;
    }
    debugPrint('TX: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    await _writeChar!.write(packet, withoutResponse: true);
  }

  bool _isWatchFacePacket(List<int> packet) {
    if (packet.length < 5) return true;
    final cmd = packet[4];
    return cmd == 0x74 || cmd == 0x6E || cmd == 0xB4 || cmd == 0xB7 || cmd == 0xBA || cmd == 0x38 || cmd == 0x19;
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
    if (_isTransferringWatchFace) return;
    await sendPacket(ProtocolParser.buildGetHRHistory());
  }
  
  // Request step history
  Future<void> requestStepHistory(int dayOffset) async {
    if (_isTransferringWatchFace) return;
    await sendPacket(ProtocolParser.buildGetStepHistory(dayOffset));
  }
  
  // Read battery
  Future<void> readBattery() async {
    if (_device == null || _isTransferringWatchFace) return;
    
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
    if (_isTransferringWatchFace) return;
    await sendPacket(ProtocolParser.buildTimeSync(DateTime.now()));
  }

  // Upload and flash custom watch face design to the watch
  Future<void> uploadCustomWatchFace(
    Uint8List rawPayload, {
    void Function(double progress)? onProgress,
  }) async {
    if (_writeChar == null) throw Exception('Not connected');

    _isTransferringWatchFace = true;

    try {
      // Negotiate MTU for high-speed streaming
      if (_device != null) {
        try {
          final mtu = await _device!.requestMtu(256);
          debugPrint('CRP: MTU for transfer = $mtu');
        } catch (e) {
          debugPrint('CRP: MTU request during transfer: $e');
        }
      }

      final payloadLen = rawPayload.length;
      final fullPayload = Uint8List(payloadLen + 8);
      fullPayload[0] = 6; // CRPWatchFaceLayoutInfo.CompressionType.JIELI
      fullPayload[1] = 0xFF;
      fullPayload[2] = 0xFF;
      fullPayload[3] = 0xFF;
      fullPayload[4] = payloadLen & 0xFF;
      fullPayload[5] = (payloadLen >> 8) & 0xFF;
      fullPayload[6] = (payloadLen >> 16) & 0xFF;
      fullPayload[7] = (payloadLen >> 24) & 0xFF;
      fullPayload.setRange(8, fullPayload.length, rawPayload);
      final totalBytes = fullPayload.length;
      const rawChunkSize = 236; // 236 raw bytes + 4 byte CRC header = 240 payload + 5 CRP header = 245 GATT packet
      final totalChunks = (totalBytes / rawChunkSize).ceil();
      debugPrint('CRP: Starting Jieli watch face transfer ($totalBytes bytes total, $totalChunks chunks)');

      // Little-Endian 4-byte total size (confirmed from decompiled com/crrepa/h1/d.java: b(long j7))
      final sizeLE = [
        totalBytes & 0xFF,
        (totalBytes >> 8) & 0xFF,
        (totalBytes >> 16) & 0xFF,
        (totalBytes >> 24) & 0xFF,
      ];

      // 1. Switch to Photo watch face mode (cmd 0xB4 [29, 1] & [35, 1])
      await sendPacket(ProtocolParser.buildPacket(0xB4, [29, 1]));
      await Future.delayed(const Duration(milliseconds: 100));
      await sendPacket(ProtocolParser.buildSwitchWatchFace(1));
      await Future.delayed(const Duration(milliseconds: 100));

      // 2. Trigger on-screen update progress animation (cmd 0xB4 [1, size_LE (4 bytes), 1])
      // Confirmed from decompiled com/crrepa/q0/e.java: line 225
      final animTriggerPacket = ProtocolParser.buildPacket(0xB4, [
        1,
        sizeLE[0],
        sizeLE[1],
        sizeLE[2],
        sizeLE[3],
        1,
      ]);
      await sendPacket(animTriggerPacket);
      debugPrint('CRP: Sent animation trigger 0xB4 0x01 (LE size: $sizeLE)');
      await Future.delayed(const Duration(milliseconds: 150));

      // 3. Initiate CrRePa background file transfer (cmd 0xB7 [0, 11, size_LE (4 bytes), 'w','f','.','b','i','n'])
      // Confirmed from decompiled com/crrepa/s0/a.java: line 181
      final b7StartPacket = ProtocolParser.buildPacket(0xB7, [
        0,
        11, // Photo watch face background file type
        sizeLE[0],
        sizeLE[1],
        sizeLE[2],
        sizeLE[3],
        119, 102, 46, 98, 105, 110, // "wf.bin"
      ]);
      await sendPacket(b7StartPacket);
      await Future.delayed(const Duration(milliseconds: 100));

      // 4. Negotiate package length (cmd 0xBA [1]) & Jieli file start (cmd 0x74 & 0x6E with size_LE)
      await sendPacket(ProtocolParser.buildPacket(0xBA, [1]));
      await Future.delayed(const Duration(milliseconds: 80));
      await sendPacket(ProtocolParser.buildPacket(0x74, sizeLE));
      await Future.delayed(const Duration(milliseconds: 80));
      await sendPacket(ProtocolParser.buildPacket(0x6E, sizeLE));
      await Future.delayed(const Duration(milliseconds: 150));

      // 5. Stream CRP-framed chunks (cmd 0x74) over GATT characteristic (0xFEE2)
      // Confirmed from decompiled com/crrepa/l0/d.java: sendFile(i7) & f.a(transBytes, b7)
      for (int i = 0; i < totalChunks; i++) {
        final start = i * rawChunkSize;
        final end = (start + rawChunkSize > totalBytes) ? totalBytes : start + rawChunkSize;
        final chunkData = fullPayload.sublist(start, end);

        final packet = _buildFramedChunkPacket(0x74, chunkData);
        await sendPacket(packet);

        onProgress?.call((i + 1) / totalChunks);
        await Future.delayed(const Duration(milliseconds: 15));
      }

      // 6. Complete transfer ACK (cmd 0x74 [0,0,0,0] & 0x6E [0,0,0,0] & 0xB7 [3])
      await Future.delayed(const Duration(milliseconds: 200));
      await sendPacket(ProtocolParser.buildPacket(0x74, [0, 0, 0, 0]));
      await Future.delayed(const Duration(milliseconds: 100));
      await sendPacket(ProtocolParser.buildPacket(0x6E, [0, 0, 0, 0]));
      await Future.delayed(const Duration(milliseconds: 100));
      await sendPacket(ProtocolParser.buildPacket(0xB7, [3]));
      await Future.delayed(const Duration(milliseconds: 600)); // Allow MCU to burn flash

      // 7. Reactivate watch face and layout sync
      await sendPacket(ProtocolParser.buildPacket(0xB4, [29, 1]));
      await Future.delayed(const Duration(milliseconds: 100));
      await sendPacket(ProtocolParser.buildSwitchWatchFace(1));
      await Future.delayed(const Duration(milliseconds: 100));
      await sendPacket(ProtocolParser.buildWatchFaceLayout(timePosition: 0, timeTopContent: 1, timeBottomContent: 2));
      debugPrint('CRP: Custom watch face transfer complete!');
    } finally {
      _isTransferringWatchFace = false;
    }
  }

  // CrRePa chunk header framing (from decompiled com/crrepa/l0/f.java: line 35-43)
  List<int> _buildFramedChunkPacket(int cmd, Uint8List chunkData) {
    final crc = _computeCrRepaCrc16(chunkData);
    final payload = Uint8List(chunkData.length + 4);
    payload[0] = 0xFE; // 254 = -2 in signed byte (f.java line 38)
    payload[1] = (crc >> 8) & 0xFF;
    payload[2] = crc & 0xFF;
    payload[3] = chunkData.length & 0xFF;
    payload.setRange(4, payload.length, chunkData);

    return ProtocolParser.buildPacket(cmd, payload);
  }

  // CrRePa CRC16 (from decompiled com/crrepa/l0/c.java: seed 65258 / 0xFEEA)
  int _computeCrRepaCrc16(Uint8List data) {
    int crc = 0xFEEA; // c.f66808a = 65258
    for (int i = 0; i < data.length; i++) {
      int v = (((crc & 0xFF) << 8) | ((crc & 0xFF00) >> 8)) ^ (data[i] & 0xFF);
      v = v ^ ((v & 0xFF) >> 4);
      v = v ^ ((v & 0xFF) << 12);
      crc = v ^ ((v & 0xFF) << 5);
    }
    return crc & 0xFFFF;
  }

  // Forget saved device
  Future<void> forgetDevice() async {
    await disconnect();
    await _storage.clearDevice();
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
    _adapterStateSub?.cancel();
    _connectionStateController.close();
    _dataController.close();
  }
}
