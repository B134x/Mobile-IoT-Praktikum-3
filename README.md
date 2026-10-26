# Mobile IoT Lab — Kelompok 1

Aplikasi Flutter dan firmware ESP32 untuk praktikum *Implementasi Komunikasi Mobile-IoT (BLE/MQTT)*. LED dan sensor DHT22 pada ESP32 dikendalikan lewat dua jalur: BLE (langsung, tanpa internet) dan MQTT (lewat broker).

Tugas pengembangan yang dipilih: **Tugas 3, grafik riwayat suhu 20 pembacaan terakhir.**

## Struktur

| Path | Isi |
|---|---|
| `lib/config.dart` | Nama kelompok, UUID BLE, broker dan topik MQTT, panjang riwayat (20) |
| `lib/ble_page.dart` | Praktikum 1 dan 3: scan, connect, LED, notify sensor, latensi BLE |
| `lib/mqtt_page.dart` | Praktikum 2 dan 3: publish/subscribe, LED, sensor, status perangkat, latensi MQTT |
| `lib/sensor_data.dart` | Model pembacaan, parser data BLE dan MQTT, riwayat 20 pembacaan |
| `lib/temperature_chart.dart` | Tugas 3: grafik garis riwayat suhu |
| `lib/latency.dart` | Ringkasan hasil pengukuran latensi |
| `firmware/p1_ble/` | Firmware Praktikum 1 (BLE) |
| `firmware/p2_mqtt/` | Firmware Praktikum 2 (MQTT) |
| `firmware/p3_ble_mqtt/` | Firmware gabungan Praktikum 3, dipakai juga untuk Tugas 3 |
| `test/` | Pengujian unit untuk parser, riwayat dan latensi |

## Rangkaian

Board yang dipakai: **Waveshare ESP32-S3 N16R8** (flash 16 MB, PSRAM 8 MB octal). LED dipindah dari GPIO 26 di modul ke **GPIO 5**, karena pada ESP32-S3 GPIO 26–32 dipakai flash/PSRAM, dan GPIO 35–37 dipakai PSRAM octal.

| Komponen | Pin komponen | Pin ESP32-S3 |
|---|---|---|
| LED | Anoda (kaki panjang) lewat resistor 220 Ω | GPIO 5 |
| LED | Katoda | GND |
| DHT22 | VCC | 3V3 |
| DHT22 | DATA (+ resistor 10 kΩ ke 3V3 jika tanpa PCB) | GPIO 4 |
| DHT22 | GND | GND |

## Firmware

1. Arduino IDE 2.x dengan board package **esp32 by Espressif**.
2. Pengaturan di menu **Tools**:

   | Opsi | Nilai |
   |---|---|
   | Board | ESP32S3 Dev Module |
   | Flash Size | 16MB (128Mb) |
   | PSRAM | OPI PSRAM |
   | Partition Scheme | Huge APP (3MB No OTA/1MB SPIFFS) |
   | USB CDC On Boot | *Enabled* jika kabel di port USB bawaan (native); *Disabled* jika di port UART |

3. Library: *DHT sensor library* (Adafruit), *Adafruit Unified Sensor*, *PubSubClient*.
4. Untuk `p2_mqtt` dan `p3_ble_mqtt`: salin `secrets.example.h` menjadi `secrets.h` di folder yang sama, lalu isi SSID dan password hotspot **2.4 GHz**. `secrets.h` tidak ikut ke GitHub.
5. Upload, lalu buka Serial Monitor pada 115200 baud.

Jika upload macet di *Connecting...*: tahan tombol BOOT, tekan dan lepas RESET, lalu lepas BOOT.

## Aplikasi

BLE tidak bisa diuji di emulator, jadi pakai HP Android fisik.

```bash
flutter pub get
flutter run --release
```

Saat pertama kali menekan **Scan perangkat**, izinkan *Perangkat di sekitar* (Android 12+) atau *Lokasi* (Android 11 ke bawah).

Broker `broker.emqx.io` bersifat publik. Jika data kelompok lain ikut masuk, ganti `kelompok` di `lib/config.dart` dan `KELOMPOK` di kedua firmware MQTT dengan nama yang lebih unik.

## Tugas 3: grafik riwayat suhu

**Cara kerja.** Setiap pembacaan, baik notify BLE (`28.5;70.2`) maupun pesan MQTT (`{"suhu":28.5,"hum":70.2}`), diubah menjadi `SensorReading` lalu disimpan di `ReadingHistory` berkapasitas 20. Saat pembacaan ke-21 masuk, yang paling lama dibuang (FIFO). Grafik digambar ulang setiap ada data baru.

**Riwayat per jalur.** Tab BLE dan tab MQTT masing-masing punya grafik sendiri. Firmware gabungan mengirim pembacaan yang sama lewat kedua jalur, jadi menggabungkannya akan membuat setiap titik muncul dua kali. Riwayat dikosongkan setiap kali koneksi baru dibuat.

**Membaca grafik.**

- Sumbu X: pembacaan ke-1 sampai ke-20, paling kiri yang terlama.
- Sumbu Y: suhu dalam °C, dengan rentang minimal 2 °C agar derau 0,1 °C tidak tampak seperti lonjakan.
- Di atas grafik: jumlah pembacaan, suhu minimum, rata-rata dan maksimum.
- Ketuk sebuah titik untuk melihat suhu dan jam pembacaannya.

Firmware gabungan mengirim data tiap 3 detik, jadi 20 pembacaan mencakup sekitar 1 menit.

**Skenario uji.**

| No | Skenario | Hasil yang diharapkan | Hasil |
|---|---|---|---|
| 1 | Hubungkan lewat BLE, tunggu 1 menit | Grafik terisi dari kiri sampai 20/20 | |
| 2 | Tunggu pembacaan ke-21 | Titik terlama hilang, grafik bergeser ke kiri | |
| 3 | Pegang sensor DHT22 selama 30 detik | Garis naik, nilai maks bertambah | |
| 4 | Ulangi skenario 1 dan 3 di tab MQTT | Perilaku sama, dari jalur MQTT | |
| 5 | Ketuk salah satu titik | Muncul suhu dan jam pembacaan | |
| 6 | Putuskan lalu hubungkan lagi | Riwayat mulai dari 0/20 | |

## Pengujian unit

```bash
flutter test
```
