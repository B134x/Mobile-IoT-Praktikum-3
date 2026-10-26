import 'dart:math';

/// Summarises latency samples in milliseconds for Praktikum 3, e.g.
/// "rata-rata 85 ms (min 60, maks 120, 10/10 sampel)".
String describeLatency(List<int> samples, int attempts) {
  if (samples.isEmpty) return 'tidak ada respons';
  final average = samples.reduce((a, b) => a + b) / samples.length;
  return 'rata-rata ${average.toStringAsFixed(0)} ms '
      '(min ${samples.reduce(min)}, maks ${samples.reduce(max)}, '
      '${samples.length}/$attempts sampel)';
}
