import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shadcn_card.dart';
import '../../core/widgets/shadcn_badge.dart';

class CaloriesPage extends StatelessWidget {
  final List<CaloriesRecord> records;
  final int? currentCalories;

  const CaloriesPage({
    super.key,
    required this.records,
    this.currentCalories,
  });

  @override
  Widget build(BuildContext context) {
    final totalCalories = records.isNotEmpty
        ? records.map((r) => r.calories).reduce((a, b) => a + b)
        : 0;
    final maxCalories = records.isNotEmpty
        ? records.map((r) => r.calories).reduce((a, b) => a > b ? a : b)
        : 0;
    final avgCalories = records.isNotEmpty
        ? records.map((r) => r.calories).reduce((a, b) => a + b) ~/ records.length
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calories'),
        actions: [
          if (currentCalories != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: ShadcnBadge(
                  text: '$currentCalories kcal',
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
            // Current Calories
            ShadcnCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories Burned',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currentCalories ?? 0}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const Text(
                    'kcal',
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
                      value: (currentCalories ?? 0) / 500,
                      backgroundColor: AppTheme.border,
                      color: AppTheme.chart2,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${((currentCalories ?? 0) / 500 * 100).toInt()}% of 500 kcal goal',
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
                    value: '$totalCalories',
                    color: AppTheme.chart2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'AVG',
                    value: '$avgCalories',
                    color: AppTheme.chart3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'BEST',
                    value: '$maxCalories',
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
                    'Calories History',
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
                                      toY: entry.value.calories.toDouble(),
                                      color: AppTheme.chart2,
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
                            '${record.calories} kcal',
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

class CaloriesRecord {
  final DateTime timestamp;
  final int calories;

  const CaloriesRecord({
    required this.timestamp,
    required this.calories,
  });
}
