import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ble_remote/latency.dart';
import 'package:ble_remote/sensor_data.dart';

void main() {
  final time = DateTime(2026, 10, 26, 14, 3, 21);

  group('SensorReading.fromBle', () {
    test('reads "suhu;kelembapan"', () {
      final r = SensorReading.fromBle(utf8.encode('28.5;70.2'), time: time);
      expect(r?.temperature, 28.5);
      expect(r?.humidity, 70.2);
      expect(r?.time, time);
    });

    test('rejects anything else', () {
      expect(SensorReading.fromBle(utf8.encode('28.5')), isNull);
      expect(SensorReading.fromBle(utf8.encode('abc;70')), isNull);
      expect(SensorReading.fromBle(utf8.encode('NaN;70')), isNull);
      expect(SensorReading.fromBle([0xff, 0xfe]), isNull);
    });
  });

  group('SensorReading.fromMqttJson', () {
    test('reads the firmware JSON', () {
      final r = SensorReading.fromMqttJson('{"suhu":28.5,"hum":70.2}');
      expect(r?.temperature, 28.5);
      expect(r?.humidity, 70.2);
    });

    test('accepts whole numbers', () {
      expect(
        SensorReading.fromMqttJson('{"suhu":28,"hum":70}')?.temperature,
        28,
      );
    });

    test('ignores foreign messages on the public broker', () {
      expect(SensorReading.fromMqttJson('ON'), isNull);
      expect(SensorReading.fromMqttJson('[1, 2]'), isNull);
      expect(SensorReading.fromMqttJson('{"suhu":"28"}'), isNull);
    });
  });

  group('ReadingHistory', () {
    test('keeps only the last readings, oldest first', () {
      final history = ReadingHistory(20);
      for (var i = 0; i < 25; i++) {
        history.add(
          SensorReading(temperature: i.toDouble(), humidity: 50, time: time),
        );
      }
      final temps = history.readings.map((r) => r.temperature).toList();
      expect(temps.length, 20);
      expect(temps.first, 5);
      expect(temps.last, 24);
    });

    test('clear empties it', () {
      final history = ReadingHistory(20)
        ..add(SensorReading(temperature: 28, humidity: 70, time: time))
        ..clear();
      expect(history.readings, isEmpty);
    });
  });

  group('describeLatency', () {
    test('summarises the samples', () {
      expect(
        describeLatency([10, 20, 30], 10),
        'rata-rata 20 ms (min 10, maks 30, 3/10 sampel)',
      );
    });

    test('reports no samples', () {
      expect(describeLatency([], 10), 'tidak ada respons');
    });
  });
}
