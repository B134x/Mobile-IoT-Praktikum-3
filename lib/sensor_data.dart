import 'dart:collection';
import 'dart:convert';

/// One temperature and humidity reading from the ESP32's DHT sensor.
class SensorReading {
  const SensorReading({
    required this.temperature,
    required this.humidity,
    required this.time,
  });

  /// Parses a BLE notification: UTF-8 text "suhu;kelembapan", e.g. "28.5;70.2".
  ///
  /// Returns null for anything else, so a malformed packet is skipped instead
  /// of crashing the page.
  static SensorReading? fromBle(List<int> bytes, {DateTime? time}) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return null;
    }
    final parts = text.trim().split(';');
    if (parts.length != 2) return null;
    return _checked(double.tryParse(parts[0]), double.tryParse(parts[1]), time);
  }

  /// Parses an MQTT sensor message: JSON `{"suhu":28.5,"hum":70.2}`.
  ///
  /// The broker is public, so anything that does not match is ignored.
  static SensorReading? fromMqttJson(String text, {DateTime? time}) {
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final temperature = json['suhu'], humidity = json['hum'];
    if (temperature is! num || humidity is! num) return null;
    return _checked(temperature.toDouble(), humidity.toDouble(), time);
  }

  static SensorReading? _checked(double? t, double? h, DateTime? time) {
    if (t == null || h == null || !t.isFinite || !h.isFinite) return null;
    return SensorReading(
      temperature: t,
      humidity: h,
      time: time ?? DateTime.now(),
    );
  }

  /// Degrees Celsius.
  final double temperature;

  /// Relative humidity in percent.
  final double humidity;

  /// When the phone received the reading.
  final DateTime time;
}

/// Keeps only the most recent [capacity] readings, oldest first.
class ReadingHistory {
  ReadingHistory(this.capacity) : assert(capacity > 0);

  final int capacity;
  final _readings = ListQueue<SensorReading>();

  List<SensorReading> get readings => List.unmodifiable(_readings);

  void add(SensorReading reading) {
    _readings.addLast(reading);
    if (_readings.length > capacity) _readings.removeFirst();
  }

  void clear() => _readings.clear();
}
