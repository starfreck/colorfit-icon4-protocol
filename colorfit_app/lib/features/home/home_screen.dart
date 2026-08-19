import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shadcn_card.dart';
import '../../core/widgets/shadcn_badge.dart';
import '../../core/widgets/shadcn_avatar.dart';
import '../../core/providers/ble_provider.dart';
import '../../core/ble/bluetooth_service.dart' as ble;
import '../../core/storage/data_storage.dart';
import '../../data/models/health_data.dart';
import '../metrics/heart_rate_page.dart';
import '../metrics/steps_page.dart';
import '../metrics/calories_page.dart';
import '../metrics/distance_page.dart';
import '../metrics/watch_faces_page.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final DataStorage _storage = DataStorage();
  HealthData _healthData = const HealthData();
  bool _hasRequestedData = false;
  bool _isSyncing = false;
  bool _hasMounted = true;

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_hasMounted && ref.read(connectionStateProvider).valueOrNull == ble.ConnectionState.connected) {
        _syncData();
      }
    });
  }

  @override
  void dispose() {
    _hasMounted = false;
    _syncTimer?.cancel();
    super.dispose();
  }

  void _loadFromStorage() {
    final hrHistory = _storage.getHeartRateHistory();
    final stepsHistory = _storage.getStepsHistory();
    setState(() {
      _healthData = HealthData(
        batteryLevel: 86,
        steps: stepsHistory.isNotEmpty ? stepsHistory.last['steps'] : 0,
        distanceKm: stepsHistory.isNotEmpty ? stepsHistory.last['distance']?.toDouble() : 0.0,
        calories: stepsHistory.isNotEmpty ? stepsHistory.last['calories'] : 0,
        currentBPM: null,
        heartRateHistory: hrHistory.map((r) => HeartRateRecord(
          timestamp: DateTime.fromMillisecondsSinceEpoch(r['timestamp']),
          bpm: r['bpm'],
        )).toList(),
      );
    });
  }


  Future<void> _syncData() async {
    if (_isSyncing) return;
    final service = ref.read(bleServiceProvider);
    if (!service.isReady || service.isTransferringWatchFace) return;
    setState(() => _isSyncing = true);
    try {
      await service.readBattery();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!service.isReady) return;
      await service.requestHRHistory();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!service.isReady) return;
      await service.requestStepHistory(0);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!service.isReady) return;
      await service.syncTime();
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      if (_hasMounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _onRefresh() async {
    await _syncData();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _requestData() async {
    if (_hasRequestedData) return;
    _hasRequestedData = true;
    final service = ref.read(bleServiceProvider);
    await Future.delayed(const Duration(seconds: 1));
    try {
      if (!service.isReady) { _hasRequestedData = false; return; }
      await service.readBattery();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!service.isReady) { _hasRequestedData = false; return; }
      await service.requestHRHistory();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!service.isReady) { _hasRequestedData = false; return; }
      await service.requestStepHistory(0);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!service.isReady) { _hasRequestedData = false; return; }
      await service.syncTime();
    } catch (e) {
      debugPrint('Error requesting data: $e');
      _hasRequestedData = false;
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedForeground))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Disconnect', style: TextStyle(color: AppTheme.destructive))),
        ],
      ),
    );
    if (result == true && _hasMounted) {
      final service = ref.read(bleServiceProvider);
      await service.disconnect();
      if (_hasMounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Disconnected from watch'),
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
    final deviceName = bleService.currentDeviceName ?? _storage.getDeviceName() ?? 'ColorFit Icon 4';
    final healthAsync = ref.watch(healthDataProvider);

    healthAsync.whenData((data) {
      if (_hasMounted) {
        setState(() { _healthData = data; _isSyncing = false; });
        _hasRequestedData = false;
      }
    });

    if (isConnected && !_hasRequestedData) {
      _requestData();
    }

    final batteryLevel = _healthData.batteryLevel;
    final steps = _healthData.steps;
    final distanceKm = _healthData.distanceKm;
    final calories = _healthData.calories;
    final currentBPM = _healthData.currentBPM;
    final heartRateHistory = _healthData.heartRateHistory;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(deviceName,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.foreground)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                if (!isConnected && !isConnecting && savedAddress != null && savedAddress.isNotEmpty) {
                                  ref.read(bleServiceProvider).tryAutoConnect();
                                }
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isConnected
                                          ? AppTheme.chart3
                                          : (isConnecting ? AppTheme.chart5 : AppTheme.destructive),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isConnected
                                        ? 'Connected'
                                        : (isConnecting
                                            ? 'Connecting...'
                                            : (savedAddress != null ? 'Disconnected (Tap to connect)' : 'Disconnected')),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isConnected
                                          ? AppTheme.chart3
                                          : (isConnecting ? AppTheme.chart5 : AppTheme.mutedForeground),
                                    ),
                                  ),
                                  if (_isSyncing) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.chart1),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (batteryLevel != null)
                            ShadcnBadge(text: '$batteryLevel%', variant: BadgeVariant.secondary),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (isConnected) {
                                _showDisconnectDialog();
                              } else if (!isConnecting && savedAddress != null && savedAddress.isNotEmpty) {
                                ref.read(bleServiceProvider).tryAutoConnect();
                              }
                            },
                            child: ShadcnAvatar(
                              child: isConnecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.chart5),
                                    )
                                  : Icon(
                                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                      size: 20,
                                      color: isConnected
                                          ? AppTheme.chart3
                                          : (savedAddress != null ? AppTheme.chart5 : AppTheme.mutedForeground),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _HealthMetric(label: 'Heart Rate',
                            value: currentBPM?.toString() ?? '--', unit: 'bpm',
                            icon: Icons.favorite, color: AppTheme.chart4, isConnected: isConnected,
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => HeartRatePage(records: heartRateHistory.map((r) =>
                                    HeartRateRecord(timestamp: r.timestamp, bpm: r.bpm)).toList(),
                                    currentBPM: currentBPM))))),
                        const SizedBox(width: 8),
                        Expanded(child: _HealthMetric(label: 'Steps',
                            value: steps?.toString() ?? '0', unit: 'steps',
                            icon: Icons.directions_walk, color: AppTheme.chart1, isConnected: isConnected,
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => StepsPage(records: heartRateHistory.map((r) =>
                                    StepsRecord(timestamp: r.timestamp, steps: 1000)).toList(),
                                    currentSteps: steps))))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _HealthMetric(label: 'Calories',
                            value: calories?.toString() ?? '0', unit: 'kcal',
                            icon: Icons.local_fire_department, color: AppTheme.chart5, isConnected: isConnected,
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => CaloriesPage(records: heartRateHistory.map((r) =>
                                    CaloriesRecord(timestamp: r.timestamp, calories: 100)).toList(),
                                    currentCalories: calories))))),
                        const SizedBox(width: 8),
                        Expanded(child: _HealthMetric(label: 'Distance',
                            value: distanceKm?.toStringAsFixed(1) ?? '0.0', unit: 'km',
                            icon: Icons.straighten, color: AppTheme.chart3, isConnected: isConnected,
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => DistancePage(records: heartRateHistory.map((r) =>
                                    DistanceRecord(timestamp: r.timestamp, distance: 1.0)).toList(),
                                    currentDistance: distanceKm))))),
                      ]),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: ShadcnCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Heart Rate',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                          if (currentBPM != null)
                            ShadcnBadge(text: '$currentBPM bpm', variant: BadgeVariant.secondary),
                        ]),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: heartRateHistory.isNotEmpty
                              ? CustomPaint(size: Size.infinite,
                                  painter: _ChartPainter(
                                      data: heartRateHistory.map((r) => r.bpm.toDouble()).toList(),
                                      color: AppTheme.chart4))
                              : Center(child: Text(
                                  isConnected ? 'Waiting for data...' : 'Connect to view data',
                                  style: const TextStyle(color: AppTheme.mutedForeground, fontSize: 13))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ShadcnCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Watch Faces',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                          ElevatedButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const WatchFacesPage())),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.card,
                              foregroundColor: AppTheme.foreground,
                            ),
                            child: const Text('Manage'),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          'Switch between photo and video watch faces',
                          style: TextStyle(fontSize: 12, color: AppTheme.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ShadcnCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today\'s Activity',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.foreground)),
                        const SizedBox(height: 16),
                        _ActivityRow(label: 'Active Time',
                            value: isConnected ? 'Syncing...' : '--', progress: 0, color: AppTheme.chart1),
                        const SizedBox(height: 12),
                        _ActivityRow(label: 'Step Goal',
                            value: '${steps ?? 0} / 10,000', progress: (steps ?? 0) / 10000, color: AppTheme.chart3),
                        const SizedBox(height: 12),
                        _ActivityRow(label: 'Calories',
                            value: '${calories ?? 0} / 1,200', progress: (calories ?? 0) / 1200, color: AppTheme.chart5),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final VoidCallback? onTap;

  const _HealthMetric({
    required this.label, required this.value, required this.unit,
    required this.icon, required this.color, this.isConnected = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ShadcnCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(icon, size: 16, color: isConnected ? color : AppTheme.muted),
              Text(label, style: TextStyle(fontSize: 12,
                  color: isConnected ? AppTheme.mutedForeground : AppTheme.muted)),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                  color: isConnected ? AppTheme.foreground : AppTheme.muted)),
              const SizedBox(width: 4),
              Padding(padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit, style: TextStyle(fontSize: 12,
                      color: isConnected ? AppTheme.mutedForeground : AppTheme.muted))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String label, value;
  final double progress;
  final Color color;

  const _ActivityRow({required this.label, required this.value, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.mutedForeground)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.foreground)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.secondary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _ChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    final path = Path();
    final width = size.width;
    final height = size.height;
    final stepX = width / (data.length - 1);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = height - (data[i] / maxValue * height * 0.8) - height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = height - (data[i - 1] / maxValue * height * 0.8) - height * 0.1;
        final controlX = (prevX + x) / 2;
        path.cubicTo(controlX, prevY, controlX, y, x, y);
      }
    }
    final fillPath = Path.from(path);
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, gradientPaint);
    paint.shader = LinearGradient(colors: [color, color]).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
