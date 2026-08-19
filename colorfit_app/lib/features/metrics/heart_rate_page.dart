import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shadcn_card.dart';
import '../../core/widgets/shadcn_badge.dart';
import '../../data/models/health_data.dart';

class HeartRatePage extends StatelessWidget {
  final List<HeartRateRecord> records;
  final int? currentBPM;

  const HeartRatePage({
    super.key,
    required this.records,
    this.currentBPM,
  });

  @override
  Widget build(BuildContext context) {
    final maxBPM = records.isNotEmpty
        ? records.map((r) => r.bpm).reduce((a, b) => a > b ? a : b)
        : 100;
    final minBPM = records.isNotEmpty
        ? records.map((r) => r.bpm).reduce((a, b) => a < b ? a : b)
        : 60;
    final avgBPM = records.isNotEmpty
        ? records.map((r) => r.bpm).reduce((a, b) => a + b) ~/ records.length
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate'),
        actions: [
          if (currentBPM != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: ShadcnBadge(
                  text: '$currentBPM bpm',
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
            // Current BPM
            ShadcnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Heart Rate',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currentBPM ?? '--'}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const Text(
                    'bpm',
                    style: TextStyle(
                      fontSize: 16,
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
                    label: 'MIN',
                    value: '$minBPM',
                    color: AppTheme.chart3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'AVG',
                    value: '$avgBPM',
                    color: AppTheme.chart1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'MAX',
                    value: '$maxBPM',
                    color: AppTheme.chart4,
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
                    'Heart Rate History',
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
                        ? LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: records.asMap().entries.map((entry) {
                                    return FlSpot(
                                      entry.key.toDouble(),
                                      entry.value.bpm.toDouble(),
                                    );
                                  }).toList(),
                                  isCurved: true,
                                  color: AppTheme.chart4,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppTheme.chart4.withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                              minY: (minBPM - 10).toDouble(),
                              maxY: (maxBPM + 10).toDouble(),
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

            // Recent readings
            ShadcnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Readings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    const Text(
                      'No readings yet',
                      style: TextStyle(color: AppTheme.mutedForeground),
                    )
                  else
                    ...records.take(10).map((record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${record.timestamp.hour}:${record.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                            ),
                          ),
                          Text(
                            '${record.bpm} bpm',
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
