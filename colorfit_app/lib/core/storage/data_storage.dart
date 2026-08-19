import 'package:hive_flutter/hive_flutter.dart';

class DataStorage {
  static const String _healthBoxName = 'health_data';
  static const String _settingsBoxName = 'settings';
  
  late Box _healthBox;
  late Box _settingsBox;
  
  static final DataStorage _instance = DataStorage._internal();
  factory DataStorage() => _instance;
  DataStorage._internal();
  
  Future<void> init() async {
    await Hive.initFlutter();
    _healthBox = await Hive.openBox(_healthBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }
  
  Map<String, dynamic> _castMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }
  
  List<Map<String, dynamic>> _castList(dynamic data) {
    if (data is List) {
      return data.map((e) => _castMap(e)).toList();
    }
    return [];
  }
  
  Future<void> saveHeartRate(int bpm, DateTime timestamp) async {
    final records = getHeartRateHistory();
    records.add({'bpm': bpm, 'timestamp': timestamp.millisecondsSinceEpoch});
    await _healthBox.put('heart_rate', records);
  }
  
  List<Map<String, dynamic>> getHeartRateHistory() {
    return _castList(_healthBox.get('heart_rate', defaultValue: []));
  }
  
  Future<void> saveSteps(int steps, DateTime timestamp) async {
    final records = getStepsHistory();
    records.add({'steps': steps, 'timestamp': timestamp.millisecondsSinceEpoch});
    await _healthBox.put('steps', records);
  }
  
  List<Map<String, dynamic>> getStepsHistory() {
    return _castList(_healthBox.get('steps', defaultValue: []));
  }
  
  Future<void> saveCalories(int calories, DateTime timestamp) async {
    final records = getCaloriesHistory();
    records.add({'calories': calories, 'timestamp': timestamp.millisecondsSinceEpoch});
    await _healthBox.put('calories', records);
  }
  
  List<Map<String, dynamic>> getCaloriesHistory() {
    return _castList(_healthBox.get('calories', defaultValue: []));
  }
  
  Future<void> saveDistance(double distance, DateTime timestamp) async {
    final records = getDistanceHistory();
    records.add({'distance': distance, 'timestamp': timestamp.millisecondsSinceEpoch});
    await _healthBox.put('distance', records);
  }
  
  List<Map<String, dynamic>> getDistanceHistory() {
    return _castList(_healthBox.get('distance', defaultValue: []));
  }
  
  Future<void> setBluetoothEnabled(bool enabled) async {
    await _settingsBox.put('bluetooth_enabled', enabled);
  }
  
  bool getBluetoothEnabled() {
    return _settingsBox.get('bluetooth_enabled', defaultValue: false);
  }
  
  Future<void> setDeviceAddress(String address) async {
    await _settingsBox.put('device_address', address);
  }
  
  String? getDeviceAddress() {
    return _settingsBox.get('device_address');
  }
  
  Future<void> setLastSync(DateTime timestamp) async {
    await _settingsBox.put('last_sync', timestamp.millisecondsSinceEpoch);
  }
  
  DateTime? getLastSync() {
    final ts = _settingsBox.get('last_sync');
    if (ts != null) {
      return DateTime.fromMillisecondsSinceEpoch(ts);
    }
    return null;
  }
  
  Future<void> clearHealthData() async {
    await _healthBox.clear();
  }
  
  Future<void> clearAll() async {
    await _healthBox.clear();
    await _settingsBox.clear();
  }
}
