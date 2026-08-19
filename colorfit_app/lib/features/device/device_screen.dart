import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shadcn_card.dart';
import '../../core/widgets/shadcn_button.dart';
import '../../core/widgets/shadcn_avatar.dart';
import '../../core/providers/ble_provider.dart';
import '../../core/storage/data_storage.dart';
import '../../core/ble/bluetooth_service.dart' as ble;

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key});

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  final DataStorage _storage = DataStorage();
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _hasPermissions = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final granted = statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.location]!.isGranted;

    if (mounted) {
      setState(() => _hasPermissions = granted);

      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth & Location permissions required'),
            backgroundColor: AppTheme.destructive,
          ),
        );
      }
    }
  }

  Future<void> _startScan() async {
    if (!_hasPermissions) {
      await _initPermissions();
      return;
    }

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable Bluetooth'),
            backgroundColor: AppTheme.destructive,
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results.where((r) => _isColorFitDevice(r)).toList();
        });
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  bool _isColorFitDevice(ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    if (name.contains('colorfit') ||
        name.contains('noise') ||
        name.contains('moyoung') ||
        name.contains('crrepa')) {
      return true;
    }

    final serviceUuids = result.advertisementData.serviceUuids;
    for (final uuid in serviceUuids) {
      final uuidStr = uuid.toString().toLowerCase();
      if (uuidStr.contains('fee2') || uuidStr.contains('fee3') || uuidStr.contains('fee5') || uuidStr.contains('fee0')) {
        return true;
      }
    }

    final manufacturerData = result.advertisementData.manufacturerData;
    for (final entry in manufacturerData.entries) {
      final data = entry.value;
      if (data.length >= 2 && data[0] == 0x4C && data[1] == 0x06) {
        return true;
      }
    }

    return false;
  }

  Future<void> _connectToAddress(String address, [String? deviceName]) async {
    try {
      final service = ref.read(bleServiceProvider);
      await service.connect(address);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${deviceName ?? "watch"}'),
            backgroundColor: AppTheme.chart3,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: AppTheme.destructive,
          ),
        );
      }
    }
  }

  Future<void> _showDisconnectDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Disconnect Watch', style: TextStyle(color: AppTheme.foreground)),
        content: const Text('Are you sure you want to disconnect from your watch?',
            style: TextStyle(color: AppTheme.mutedForeground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedForeground)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect', style: TextStyle(color: AppTheme.destructive)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final service = ref.read(bleServiceProvider);
      await service.disconnect();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Disconnected from watch'),
          backgroundColor: AppTheme.mutedForeground,
        ));
      }
    }
  }

  Future<void> _forgetDevice() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Forget Watch', style: TextStyle(color: AppTheme.foreground)),
        content: const Text('This will remove the saved watch session. You will need to scan and pair again.',
            style: TextStyle(color: AppTheme.mutedForeground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedForeground)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Forget', style: TextStyle(color: AppTheme.destructive)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final service = ref.read(bleServiceProvider);
      await service.forgetDevice();
      setState(() {});
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Watch session forgotten'),
          backgroundColor: AppTheme.mutedForeground,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final isConnected = connectionState.valueOrNull == ble.ConnectionState.connected;
    final isConnecting = connectionState.valueOrNull == ble.ConnectionState.connecting;
    final bleService = ref.watch(bleServiceProvider);
    
    final savedAddress = _storage.getDeviceAddress();
    final savedName = _storage.getDeviceName() ?? 'ColorFit Icon 4';
    final currentAddress = bleService.currentDeviceAddress ?? savedAddress;
    final currentName = bleService.currentDeviceName ?? savedName;

    // Filter out the connected/saved device from the available devices scan list
    final availableDevices = _scanResults.where((r) {
      final devAddress = r.device.remoteId.str.toLowerCase();
      if (isConnected && currentAddress != null) {
        if (devAddress == currentAddress.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Devices',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                            ? 'Connected to watch'
                            : (isConnecting ? 'Connecting...' : 'Manage your device connection'),
                        style: TextStyle(
                          fontSize: 14,
                          color: isConnected
                              ? AppTheme.chart3
                              : (isConnecting ? AppTheme.chart5 : AppTheme.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                  ShadcnButton(
                    onPressed: _isScanning ? null : _startScan,
                    variant: ButtonVariant.outline,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isScanning)
                          const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.foreground))
                        else
                          const Icon(Icons.search, size: 16),
                        const SizedBox(width: 8),
                        Text(_isScanning ? 'Scanning...' : 'Scan'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Connected Device Section
              if (isConnected) ...[
                const Text('Connected Device',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                const SizedBox(height: 8),
                ShadcnCard(
                  child: Row(
                    children: [
                      const ShadcnAvatar(child: Icon(Icons.watch, size: 20, color: AppTheme.chart3)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentName,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                            const SizedBox(height: 2),
                            Text('Active • ${currentAddress ?? ""}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.chart3)),
                          ],
                        ),
                      ),
                      ShadcnButton(
                        onPressed: _showDisconnectDialog,
                        variant: ButtonVariant.destructive,
                        size: ButtonSize.sm,
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (savedAddress != null && savedAddress.isNotEmpty) ...[
                // Saved Session (when disconnected)
                const Text('Saved Watch Session',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                const SizedBox(height: 8),
                ShadcnCard(
                  child: Row(
                    children: [
                      const ShadcnAvatar(child: Icon(Icons.watch, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(savedName,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                            const SizedBox(height: 2),
                            Text(isConnecting ? 'Connecting...' : savedAddress,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isConnecting ? AppTheme.chart5 : AppTheme.mutedForeground,
                                )),
                          ],
                        ),
                      ),
                      if (isConnecting)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.chart5),
                        )
                      else ...[
                        ShadcnButton(
                          onPressed: () => _connectToAddress(savedAddress, savedName),
                          variant: ButtonVariant.default$,
                          size: ButtonSize.sm,
                          child: const Text('Connect'),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.mutedForeground),
                          tooltip: 'Forget Watch',
                          onPressed: _forgetDevice,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Available Devices Section (Filtered to never show already connected device)
              if (availableDevices.isNotEmpty) ...[
                Text('Available Devices (${availableDevices.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableDevices.length,
                    itemBuilder: (context, index) {
                      final result = availableDevices[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DeviceTile(
                          result: result,
                          onTap: () => _connectToAddress(result.device.remoteId.str, result.device.platformName),
                        ),
                      );
                    },
                  ),
                ),
              ] else if (!_isScanning) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isConnected ? Icons.check_circle_outline : Icons.bluetooth_searching,
                          size: 48,
                          color: isConnected ? AppTheme.chart3 : AppTheme.muted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isConnected ? 'Watch connected and active' : 'No other devices found',
                          style: const TextStyle(color: AppTheme.mutedForeground, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isConnected
                              ? 'Your ColorFit Icon 4 is paired and ready'
                              : 'Tap Scan to search for nearby Bluetooth devices',
                          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2, color: AppTheme.chart1),
                        SizedBox(height: 16),
                        Text('Scanning for ColorFit devices...',
                            style: TextStyle(color: AppTheme.mutedForeground, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;

  const _DeviceTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'Unknown Device';
    final isWatch = name.toLowerCase().contains('colorfit') ||
        name.toLowerCase().contains('noise') ||
        name.toLowerCase().contains('moyoung');

    return ShadcnCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          ShadcnAvatar(child: Icon(isWatch ? Icons.watch : Icons.bluetooth, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                    if (isWatch) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.chart3.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ColorFit',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.chart3)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(result.device.remoteId.str,
                    style: const TextStyle(fontSize: 12, color: AppTheme.mutedForeground)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${result.rssi} dBm',
                  style: TextStyle(fontSize: 12, color: result.rssi > -80 ? AppTheme.chart3 : AppTheme.chart5)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right, size: 16, color: AppTheme.mutedForeground),
            ],
          ),
        ],
      ),
    );
  }
}
