import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'sensor_data.dart';

/// Tugas 3: line chart of the most recent temperature readings, oldest on the
/// left. The x axis always spans [capacity] readings, so the line grows from
/// the left until the history is full and then scrolls.
class TemperatureChart extends StatelessWidget {
  const TemperatureChart({
    super.key,
    required this.readings,
    required this.capacity,
  });

  final List<SensorReading> readings;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat suhu, $capacity pembacaan terakhir',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(_summary(), style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: readings.length < 2
              ? const Center(child: Text('Menunggu data...'))
              : LineChart(_chartData(theme)),
        ),
      ],
    );
  }

  String _summary() {
    if (readings.isEmpty) return '0/$capacity pembacaan';
    final temps = readings.map((r) => r.temperature);
    final average = temps.reduce((a, b) => a + b) / readings.length;
    return '${readings.length}/$capacity pembacaan · '
        'min ${temps.reduce(min).toStringAsFixed(1)} · '
        'rata-rata ${average.toStringAsFixed(1)} · '
        'maks ${temps.reduce(max).toStringAsFixed(1)} °C';
  }

  LineChartData _chartData(ThemeData theme) {
    final color = theme.colorScheme.primary;
    final labelStyle = theme.textTheme.labelSmall;
    final temps = readings.map((r) => r.temperature);
    final low = temps.reduce(min), high = temps.reduce(max);

    // At least a 2 °C window, so 0.1 °C of sensor noise is not drawn as a peak.
    final middle = (low + high) / 2;
    final halfSpan = max((high - low) / 2 + 0.5, 1.0);
    final minY = (middle - halfSpan).floorToDouble();
    final maxY = (middle + halfSpan).ceilToDouble();
    final yStep = maxY - minY <= 6 ? 1.0 : ((maxY - minY) / 5).ceilToDouble();

    Widget label(double value, TitleMeta meta) => SideTitleWidget(
      meta: meta,
      child: Text(value.toStringAsFixed(0), style: labelStyle),
    );

    return LineChartData(
      minX: 1,
      maxX: capacity.toDouble(),
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (final (i, r) in readings.indexed)
              FlSpot(i + 1.0, r.temperature),
          ],
          color: color,
          barWidth: 2.5,
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.12),
          ),
        ),
      ],
      gridData: FlGridData(drawVerticalLine: false, horizontalInterval: yStep),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: yStep,
            getTitlesWidget: label,
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: Text('Pembacaan ke-', style: labelStyle),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: 5,
            getTitlesWidget: label,
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => theme.colorScheme.inverseSurface,
          getTooltipItems: (spots) => [
            for (final spot in spots)
              LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} °C\n'
                '${_clock(readings[spot.spotIndex].time)}',
                TextStyle(color: theme.colorScheme.onInverseSurface),
              ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime t) => [
    t.hour,
    t.minute,
    t.second,
  ].map((v) => v.toString().padLeft(2, '0')).join(':');
}
