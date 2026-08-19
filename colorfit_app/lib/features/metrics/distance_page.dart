import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shadcn_card.dart';
import '../../core/widgets/shadcn_badge.dart';

class DistancePage extends StatelessWidget {
  final List<DistanceRecord> records;
  final double? currentDistance;

  const DistancePage({
    super.key,
    required this.records,
    this.currentDistance,
  });

  @override
  Widget build(BuildContext context) {
    final totalDistance = records.isNotEmpty
        ? records.map((r) => r.distance).reduce((a, b) => a + b)
        : 0.0;
    final maxDistance = records.isNotEmpty
        ? records.map((r) => r.distance).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final avgDistance = records.isNotEmpty
        ? records.map((r) => r.distance).reduce((a, b) => a + b) / records.length
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Distance'),
        actions: [
          if (currentDistance != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: ShadcnBadge(
                  text: '${currentDistance?.toStringAsFixed(2)} km',
                  variant: BadgeVariant.secondary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Current Distance
            ShadcnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distance Traveled',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (currentDistance ?? 0.0).toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const Text(
                    'km',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (currentDistance ?? 0.0) / 8.0,
                      backgroundColor: AppTheme.border,
                      color: AppTheme.chart3,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${((currentDistance ?? 0.0) / 8.0 * 100).toInt()}% of 8 km goal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'TOTAL',
                    value: totalDistance.toStringAsFixed(1),
                    color: AppTheme.chart3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'AVG',
                    value: avgDistance.toStringAsFixed(1),
                    color: AppTheme.chart4,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'BEST',
                    value: maxDistance.toStringAsFixed(1),
                    color: AppTheme.chart1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chart
            ShadcnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distance History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: records.isNotEmpty
                        ? BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: records.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.distance,
                                      color: AppTheme.chart3,
                                      width: 16,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'No data available',
                              style: TextStyle(color: AppTheme.mutedForeground),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recent records
            ShadcnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Records',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    const Text(
                      'No records yet',
                      style: TextStyle(color: AppTheme.mutedForeground),
                    )
                  else
                    ...records.take(10).map((record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${record.timestamp.day}/${record.timestamp.month}',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                          Text(
                            '${record.distance.toStringAsFixed(2)} km',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ShadcnCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DistanceRecord {
  final DateTime timestamp;
  final double distance;

  const DistanceRecord({
    required this.timestamp,
    required this.distance,
  });
}
