import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'config.dart';
import 'latency.dart';
import 'sensor_data.dart';
import 'temperature_chart.dart';

/// Praktikum 2 and 3: the phone as MQTT client, talking to the ESP32 only
/// through topics on the broker.
class MqttPage extends StatefulWidget {
  const MqttPage({super.key});

  @override
  State<MqttPage> createState() => _MqttPageState();
}

class _MqttPageState extends State<MqttPage> {
  final _history = ReadingHistory(historyLength);
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;
  bool _connected = false;
  bool _connecting = false;
  bool _measuring = false;
  bool _ledOn = false;
  SensorReading? _latest;
  String _device = 'tidak diketahui';
  String _status = 'Belum terhubung';
  String _latMqtt = '-';

  // Praktikum 3: the latency loop waits for led/state to echo this command.
  Completer<void>? _waiting;
  String _expect = '';

  @override
  void dispose() {
    _updatesSub?.cancel();
    _client?.onDisconnected = null;
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    final id = 'flutter-$kelompok-${DateTime.now().millisecondsSinceEpoch}';
    final c = MqttServerClient(host, id)
      ..port = port
      ..keepAlivePeriod = 30
      ..onDisconnected = _onDisconnected
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(id)
          .startClean();
    c.logging(on: false);

    setState(() {
      _connecting = true;
      _status = 'Menghubungkan...';
    });
    String? failure;
    try {
      await c.connect();
      if (c.connectionStatus?.state != MqttConnectionState.connected) {
        failure = 'broker menolak (${c.connectionStatus?.returnCode})';
      }
    } catch (e) {
      failure = '$e';
    }
    if (failure != null || !mounted) {
      // Our own disconnect must not be reported as "Terputus dari broker".
      c.onDisconnected = null;
      c.disconnect();
      if (mounted) {
        setState(() {
          _connecting = false;
          _status = 'Gagal: $failure';
        });
      }
      return;
    }

    _updatesSub = c.updates?.listen(_onMessage);
    c.subscribe(tSensor, MqttQos.atMostOnce);
    c.subscribe(tLedState, MqttQos.atLeastOnce);
    c.subscribe(tStatus, MqttQos.atLeastOnce);
    _history.clear();
    setState(() {
      _client = c;
      _connected = true;
      _connecting = false;
      _latest = null;
      _latMqtt = '-';
      _status = 'Terhubung ke $host';
    });
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    if (!mounted) return;
    setState(() {
      // A batch can hold several messages; the module read only the first.
      for (final event in events) {
        final message = event.payload;
        if (message is! MqttPublishMessage) continue;
        _handle(
          event.topic,
          MqttPublishPayload.bytesToStringAsString(message.payload.message),
        );
      }
    });
  }

  void _handle(String topic, String text) {
    if (topic == tSensor) {
      final reading = SensorReading.fromMqttJson(text);
      if (reading != null) {
        _latest = reading;
        _history.add(reading);
      }
    } else if (topic == tLedState) {
      _ledOn = text == 'ON';
      final waiting = _waiting;
      if (waiting != null && !waiting.isCompleted && text == _expect) {
        waiting.complete();
      }
    } else if (topic == tStatus) {
      _device = text;
    }
  }

  void _onDisconnected() {
    _updatesSub?.cancel();
    _updatesSub = null;
    _client = null;
    if (!mounted) return;
    setState(() {
      _connected = false;
      _status = 'Terputus dari broker';
    });
  }

  void _publish(String topic, String text) {
    final c = _client;
    if (c?.connectionStatus?.state != MqttConnectionState.connected) return;
    final b = MqttClientPayloadBuilder()..addString(text);
    c!.publishMessage(topic, MqttQos.atLeastOnce, b.payload!);
  }

  // Praktikum 3: time from publishing a command until led/state comes back
  // from the ESP32 through the broker.
  Future<void> _measureLatency() async {
    if (_measuring) return;
    const attempts = 10;
    setState(() {
      _measuring = true;
      _latMqtt = 'mengukur...';
    });
    final samples = <int>[];
    for (var i = 0; i < attempts && _connected; i++) {
      final cmd = i.isEven ? 'ON' : 'OFF';
      _expect = cmd;
      _waiting = Completer<void>();
      final sw = Stopwatch()..start();
      _publish(tLed, cmd);
      try {
        await _waiting!.future.timeout(const Duration(seconds: 3));
        samples.add(sw.elapsedMilliseconds);
      } on TimeoutException {
        // No echo within 3 seconds: the sample is dropped.
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    _waiting = null;
    if (!mounted) return;
    setState(() {
      _measuring = false;
      _latMqtt = describeLatency(samples, attempts);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MQTT Controller',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(_status),
          const SizedBox(height: 12),
          if (!_connected)
            ElevatedButton(
              onPressed: _connecting ? null : _connect,
              child: const Text('Hubungkan'),
            )
          else
            Expanded(child: _connectedView()),
        ],
      ),
    );
  }

  Widget _connectedView() {
    final latest = _latest;
    return ListView(
      children: [
        Text('Perangkat: $_device'),
        SwitchListTile(
          title: const Text('LED (kondisi nyata dari ESP32)'),
          value: _ledOn,
          onChanged: _measuring
              ? null
              : (v) => _publish(tLed, v ? 'ON' : 'OFF'),
        ),
        Card(
          child: ListTile(
            title: Text(
              'Suhu: ${latest?.temperature.toStringAsFixed(1) ?? '-'} °C',
            ),
            subtitle: Text(
              'Kelembapan: ${latest?.humidity.toStringAsFixed(1) ?? '-'} %',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TemperatureChart(
              readings: _history.readings,
              capacity: _history.capacity,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _measuring ? null : _measureLatency,
          child: const Text('Ukur latensi (10 kali)'),
        ),
        Text('Latensi MQTT: $_latMqtt'),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _client?.disconnect(),
          child: const Text('Putuskan'),
        ),
      ],
    );
  }
}
