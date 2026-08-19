import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shadcn_card.dart';
import '../../core/widgets/shadcn_badge.dart';
import '../../core/protocol/parser.dart';
import '../../core/providers/ble_provider.dart';
import '../../core/storage/data_storage.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _bluetoothEnabled = false;
  bool _locationEnabled = false;
  bool _notificationsEnabled = false;
  bool _is24Hour = true;
  final DataStorage _storage = DataStorage();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadTimeFormat();
  }

  Future<void> _loadTimeFormat() async {
    final is24Hour = _storage.getBluetoothEnabled() ? true : true;
    setState(() => _is24Hour = is24Hour);
  }

  Future<void> _checkPermissions() async {
    final bluetoothEnabled = await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
    final locationEnabled = await Permission.location.isGranted;
    final notificationsEnabled = await Permission.notification.isGranted;

    setState(() {
      _bluetoothEnabled = bluetoothEnabled;
      _locationEnabled = locationEnabled;
      _notificationsEnabled = notificationsEnabled;
    });
  }

  Future<void> _toggleBluetooth(bool value) async {
    if (value) {
      final granted = await _requestBluetoothPermissions();
      if (granted) {
        try {
          await FlutterBluePlus.turnOn();
          setState(() => _bluetoothEnabled = true);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to enable Bluetooth')),
            );
          }
        }
      }
    } else {
      try {
        // Note: turnOff is deprecated in Android SDK 33
        // For Android 13+, user needs to manually disable Bluetooth
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please disable Bluetooth from system settings')),
          );
        }
        setState(() => _bluetoothEnabled = false);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to disable Bluetooth')),
          );
        }
      }
    }
  }

  Future<bool> _requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _syncTime() async {
    final service = ref.read(bleServiceProvider);
    if (!service.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to watch')),
        );
      }
      return;
    }

    try {
      await service.sendPacket(ProtocolParser.buildTimeSync(DateTime.now()));
      await Future.delayed(const Duration(milliseconds: 300));
      await service.sendPacket(ProtocolParser.buildTimezoneSync(DateTime.now()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time synced'), backgroundColor: Color(0xFF1DB954)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleTimeFormat(bool value) async {
    setState(() => _is24Hour = value);

    final service = ref.read(bleServiceProvider);
    if (!service.isReady) return;

    try {
      await service.sendPacket(ProtocolParser.buildSetTimeSystem(value));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your device and preferences',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),

            // Bluetooth Section
            const Text(
              'Connectivity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            ShadcnCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.bluetooth,
                    title: 'Bluetooth',
                    subtitle: _bluetoothEnabled ? 'Enabled' : 'Disabled',
                    trailing: Switch(
                      value: _bluetoothEnabled,
                      onChanged: _toggleBluetooth,
                      activeThumbColor: AppTheme.primary,
                    ),
                    showDivider: true,
                  ),
                  _SettingsTile(
                    icon: Icons.location_on,
                    title: 'Location',
                    subtitle: _locationEnabled ? 'Granted' : 'Required for BLE scanning',
                    trailing: _locationEnabled
                        ? const ShadcnBadge(
                            text: 'On',
                            variant: BadgeVariant.secondary,
                          )
                        : IconButton(
                            icon: const Icon(Icons.warning, color: AppTheme.chart5),
                            onPressed: () async {
                              await openAppSettings();
                            },
                          ),
                    showDivider: true,
                  ),
                  _SettingsTile(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: _notificationsEnabled ? 'Granted' : 'Optional',
                    trailing: _notificationsEnabled
                        ? const ShadcnBadge(
                            text: 'On',
                            variant: BadgeVariant.secondary,
                          )
                        : IconButton(
                            icon: const Icon(Icons.settings, color: AppTheme.mutedForeground),
                            onPressed: () async {
                              await openAppSettings();
                            },
                          ),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Device Section
            const Text(
              'Device',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            ShadcnCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.sync,
                    title: 'Sync Time',
                    subtitle: 'Sync watch time with phone',
                    onTap: _syncTime,
                  ),
                  _SettingsTile(
                    icon: Icons.access_time,
                    title: 'Time Format',
                    subtitle: _is24Hour ? '24-hour (14:30)' : '12-hour (2:30 PM)',
                    trailing: Switch(
                      value: _is24Hour,
                      onChanged: _toggleTimeFormat,
                      activeThumbColor: AppTheme.primary,
                    ),
                    showDivider: true,
                  ),
                  _SettingsTile(
                    icon: Icons.bluetooth,
                    title: 'Bond Device',
                    subtitle: 'Pair with watch',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: 'Device Info',
                    subtitle: 'MOYOUNG-V2',
                    trailing: const ShadcnBadge(
                      text: 'Connected',
                      variant: BadgeVariant.secondary,
                    ),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.battery_std,
                    title: 'Battery',
                    subtitle: '86%',
                    trailing: const ShadcnBadge(
                      text: 'Good',
                      variant: BadgeVariant.outline,
                    ),
                    onTap: () {},
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data Section
            const Text(
              'Data',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            ShadcnCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Cloud Sync',
                    subtitle: 'Disabled',
                    trailing: const ShadcnBadge(
                      text: 'Off',
                      variant: BadgeVariant.outline,
                    ),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.download_outlined,
                    title: 'Export Data',
                    subtitle: 'Export health data as JSON',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.delete_outline,
                    title: 'Clear Data',
                    subtitle: 'Remove all local data',
                    onTap: () {},
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About Section
            const Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            ShadcnCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.code,
                    title: 'Protocol',
                    subtitle: 'CrRePa / Jieli CRP',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.smartphone,
                    title: 'Version',
                    subtitle: '1.0.0',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.code_outlined,
                    title: 'Source Code',
                    subtitle: 'github.com/colorfit',
                    onTap: () {},
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: AppTheme.mutedForeground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ] else if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.muted,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 48,
            color: AppTheme.border,
          ),
      ],
    );
  }
}
