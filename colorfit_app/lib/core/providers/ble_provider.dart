import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/bluetooth_service.dart';
import '../../data/models/health_data.dart';

final bleServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(() => service.dispose());
  return service;
});

final connectionStateProvider = StreamProvider<ConnectionState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.connectionState;
});

final healthDataProvider = StreamProvider<HealthData>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.dataStream;
});
