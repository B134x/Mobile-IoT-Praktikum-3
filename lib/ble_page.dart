import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';
import 'latency.dart';
import 'sensor_data.dart';
import 'temperature_chart.dart';

/// Praktikum 1 and 3: the phone as BLE client of the ESP32's GATT server.
class BlePage extends StatefulWidget {
  const BlePage({super.key});

  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  final _history = ReadingHistory(historyLength);
  List<ScanResult> _results = [];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _ledChar;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _scanning = false;
  bool _connecting = false;
  bool _measuring = false;
  bool _ledOn = false;
  SensorReading? _latest;
  String _status = 'Belum terhubung';
  String _latBle = '-';

  @override
  void initState() {
    super.initState();
    // startScan returns as soon as scanning starts; this stream says when the
    // 6-second timeout has stopped it.
    _scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() {
        if (_scanning && !scanning && !_connecting && _device == null) {
          _status = 'Pemindaian selesai';
        }
        _scanning = scanning;
      });
    });
  }

  @override
  void dispose() {
    _scanningSub?.cancel();
    _scanSub?.cancel();
    _notifySub?.cancel();
    _connSub?.cancel();
    _device?.disconnect();
    super.dispose();
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  Future<void> _scan() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    // Android 12 and newer need these two. Android 11 and older always report
    // them as granted and need location instead (see the troubleshooting table).
    if (statuses[Permission.bluetoothScan]?.isGranted != true ||
        statuses[Permission.bluetoothConnect]?.isGranted != true) {
      _setStatus('Izin "Perangkat di sekitar" belum diberikan');
      return;
    }

    final adapter = await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) {
      _setStatus('Aktifkan Bluetooth terlebih dahulu');
      return;
    }

    if (!mounted) return;
    setState(() {
      _results = [];
      _status = 'Memindai...';
    });
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((r) {
      if (mounted) setState(() => _results = r);
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: const Duration(seconds: 6),
      );
    } catch (e) {
      _setStatus('Gagal memindai: $e');
    }
  }

  Future<void> _connect(BluetoothDevice d) async {
    setState(() {
      _connecting = true;
      _status = 'Menghubungkan...';
    });
    await FlutterBluePlus.stopScan();
    try {
      await d.connect(timeout: const Duration(seconds: 10));
    } catch (e) {
      if (mounted) setState(() => _connecting = false);
      _setStatus('Gagal terhubung: $e');
      return;
    }

    await _connSub?.cancel();
    _connSub = d.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) _onDisconnected();
    });

    try {
      BluetoothCharacteristic? ledChar, sensorChar;
      for (final s in await d.discoverServices()) {
        if (s.uuid != Guid(serviceUuid)) continue;
        for (final c in s.characteristics) {
          if (c.uuid == Guid(ledUuid)) ledChar = c;
          if (c.uuid == Guid(sensorUuid)) sensorChar = c;
        }
      }
      if (ledChar == null || sensorChar == null) {
        await _abort(d, 'Characteristic tidak ditemukan, cek UUID firmware');
        return;
      }

      await _notifySub?.cancel();
      _notifySub = sensorChar.onValueReceived.listen(_onSensorData);
      await sensorChar.setNotifyValue(true);
      // Show the LED as it really is (the combined firmware keeps it current).
      final led = await ledChar.read();

      _history.clear();
      if (!mounted) return;
      setState(() {
        _device = d;
        _ledChar = ledChar;
        _ledOn = led.isNotEmpty && led.first == 1;
        _latest = null;
        _latBle = '-';
        _status = 'Terhubung ke ${d.platformName}';
      });
    } catch (e) {
      await _abort(d, 'Gagal menyiapkan koneksi: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// Gives up on a half-set-up connection without the disconnect handler
  /// overwriting the reason.
  Future<void> _abort(BluetoothDevice d, String reason) async {
    await _connSub?.cancel();
    _connSub = null;
    await d.disconnect();
    _setStatus(reason);
  }

  void _onSensorData(List<int> value) {
    final reading = SensorReading.fromBle(value);
    if (reading == null || !mounted) return;
    setState(() {
      _latest = reading;
      _history.add(reading);
    });
  }

  void _onDisconnected() {
    _notifySub?.cancel();
    _notifySub = null;
    if (!mounted) return;
    setState(() {
      _status = 'Terputus';
      _device = null;
      _ledChar = null;
    });
  }

  Future<void> _setLed(bool on) async {
    final c = _ledChar;
    if (c == null) return;
    try {
      await c.write([on ? 1 : 0]);
      if (mounted) setState(() => _ledOn = on);
    } catch (e) {
      _setStatus('Gagal mengirim perintah LED: $e');
    }
  }

  Future<void> _disconnect() async {
    await _device?.disconnect();
  }

  // Praktikum 3: time from a write command until the ESP32's write response.
  Future<void> _measureLatency() async {
    final c = _ledChar;
    if (c == null || _measuring) return;
    const attempts = 10;
    setState(() {
      _measuring = true;
      _latBle = 'mengukur...';
    });
    final samples = <int>[];
    String? failure;
    try {
      for (var i = 0; i < attempts; i++) {
        final sw = Stopwatch()..start();
        await c.write([i.isEven ? 1 : 0]);
        sw.stop();
        samples.add(sw.elapsedMilliseconds);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      failure = '$e';
    }
    if (!mounted) return;
    setState(() {
      _measuring = false;
      // The last successful write decides the LED: even index = ON.
      if (samples.isNotEmpty) _ledOn = (samples.length - 1).isEven;
      _latBle = failure == null
          ? describeLatency(samples, attempts)
          : 'gagal setelah ${samples.length} sampel: $failure';
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
            'BLE Controller',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(_status),
          const SizedBox(height: 12),
          Expanded(child: _device == null ? _scanView() : _connectedView()),
        ],
      ),
    );
  }

  Widget _scanView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: _scanning || _connecting ? null : _scan,
          child: Text(_scanning ? 'Memindai...' : 'Scan perangkat'),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final r in _results)
                ListTile(
                  title: Text(
                    r.device.platformName.isEmpty
                        ? r.device.remoteId.str
                        : r.device.platformName,
                  ),
                  subtitle: Text('RSSI ${r.rssi} dBm'),
                  enabled: !_connecting,
                  onTap: () => _connect(r.device),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _connectedView() {
    final latest = _latest;
    return ListView(
      children: [
        SwitchListTile(
          title: const Text('LED'),
          value: _ledOn,
          onChanged: _measuring ? null : _setLed,
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
        Text('Latensi BLE: $_latBle'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _disconnect, child: const Text('Putuskan')),
      ],
    );
  }
}
