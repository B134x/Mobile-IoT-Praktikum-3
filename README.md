# Mobile IoT < Kelompok 1 >

Aplikasi Flutter dan firmware ESP32 untuk praktikum *Implementasi Komunikasi Mobile-IoT (BLE/MQTT)*. LED dan sensor DHT22 pada ESP32 dikendalikan lewat dua jalur: BLE (langsung, tanpa internet) dan MQTT (lewat broker).

Tugas pengembangan Kelompok 1: **Tugas 3, grafik riwayat suhu 20 pembacaan terakhir.**

## Pilih board

Rangkaian dan pengaturan Arduino IDE berbeda untuk tiap board. Firmware dan aplikasinya sama; pin LED dipilih otomatis saat firmware dikompilasi.

[![ESP32-S3 N16R8](https://img.shields.io/badge/ESP32--S3-N16R8-1565c0?style=for-the-badge&logo=espressif&logoColor=white)](docs/esp32-s3.md) [![ESP32 DevKit V1](https://img.shields.io/badge/ESP32-DevKit%20V1-37474f?style=for-the-badge&logo=espressif&logoColor=white)](docs/esp32-devkit-v1.md)

- **ESP32-S3 N16R8:** board yang dipakai Kelompok 1.
- **ESP32 DevKit V1:** board bawaan modul.

## Isi repositori

| Path | Isi |
|---|---|
| `lib/config.dart` | Nama kelompok, UUID BLE, broker dan topik MQTT, panjang riwayat (20) |
| `lib/ble_page.dart` | Praktikum 1 dan 3: scan, connect, LED, notify sensor, latensi BLE |
| `lib/mqtt_page.dart` | Praktikum 2 dan 3: publish/subscribe, LED, sensor, status perangkat, latensi MQTT |
| `lib/sensor_data.dart` | Model pembacaan, parser data BLE dan MQTT, riwayat 20 pembacaan |
| `lib/temperature_chart.dart` | Tugas 3: grafik garis riwayat suhu |
| `lib/latency.dart` | Ringkasan hasil pengukuran latensi |
| `firmware/` | Firmware ESP32 untuk Praktikum 1, 2 dan 3 |
| `docs/` | Rangkaian dan pengaturan per board |
| `test/` | Pengujian unit untuk parser, riwayat dan latensi |

## Firmware

### Persiapan

1. Pasang Arduino IDE 2.x. Di **File → Preferences**, tambahkan `https://espressif.github.io/arduino-esp32/package_esp32_index.json` pada *Additional boards manager URLs*, lalu pasang **esp32 by Espressif Systems** dari Boards Manager.
2. Pasang library dari Library Manager: *DHT sensor library* (Adafruit), *Adafruit Unified Sensor* dan *PubSubClient*.
3. Atur board di menu **Tools** sesuai halaman board di atas.

### Kredensial WiFi

Firmware MQTT membaca nama dan password WiFi dari `secrets.h`. Di folder `p2_mqtt` dan `p3_ble_mqtt`, salin `secrets.example.h` menjadi `secrets.h`, lalu isi dengan hotspot **2.4 GHz**. ESP32 tidak mendukung 5 GHz. File `secrets.h` tidak ikut ke GitHub.

### Urutan upload

| Folder | Untuk | Butuh WiFi |
|---|---|---|
| `firmware/p1_ble/` | Praktikum 1 (BLE) | Tidak |
| `firmware/p2_mqtt/` | Praktikum 2 (MQTT) | Ya |
| `firmware/p3_ble_mqtt/` | Praktikum 3 dan Tugas 3 (BLE dan MQTT sekaligus) | Ya |

Setiap firmware menggantikan firmware sebelumnya. Setelah upload, buka Serial Monitor pada 115200 baud.

## Aplikasi

### Menjalankan

BLE tidak bisa diuji di emulator, jadi gunakan HP Android fisik.

```bash
flutter pub get
flutter run --release
```

Untuk membuat APK yang bisa dibagikan ke anggota kelompok:

```bash
flutter build apk --release
```

Hasilnya ada di `build/app/outputs/flutter-apk/app-release.apk`.

### Izin

Saat pertama kali menekan **Scan perangkat**, izinkan *Perangkat di sekitar* (Android 12 ke atas) atau *Lokasi* (Android 11 ke bawah).

### Broker publik

Broker `broker.emqx.io` bisa dipakai siapa saja. Jika data kelompok lain ikut masuk, ganti `kelompok` di `lib/config.dart` dan `KELOMPOK` di kedua firmware MQTT dengan nama yang lebih unik.

## Tugas 3: grafik riwayat suhu

### Cara kerja

Setiap pembacaan, baik notify BLE (`28.5;70.2`) maupun pesan MQTT (`{"suhu":28.5,"hum":70.2}`), diubah menjadi `SensorReading` lalu disimpan di `ReadingHistory` berkapasitas 20. Saat pembacaan ke-21 masuk, yang paling lama dibuang. Grafik digambar ulang setiap ada data baru.

Tab BLE dan tab MQTT masing-masing punya grafik sendiri. Firmware gabungan mengirim pembacaan yang sama lewat kedua jalur, jadi menggabungkannya akan membuat setiap titik muncul dua kali. Riwayat dikosongkan setiap kali koneksi baru dibuat.

### Membaca grafik

- **Sumbu X:** pembacaan ke-1 sampai ke-20, paling kiri yang terlama.
- **Sumbu Y:** suhu dalam °C, dengan rentang minimal 2 °C agar derau 0,1 °C tidak tampak seperti lonjakan.
- **Ringkasan di atas grafik:** jumlah pembacaan, suhu minimum, rata-rata dan maksimum.
- **Titik:** ketuk untuk melihat suhu dan jam pembacaannya.

Firmware gabungan mengirim data tiap 3 detik, jadi 20 pembacaan mencakup sekitar 1 menit.

### Skenario uji

| No | Skenario | Hasil yang diharapkan |
|---|---|---|
| 1 | Hubungkan lewat BLE, tunggu 1 menit | Grafik terisi dari kiri sampai 20/20 |
| 2 | Tunggu pembacaan ke-21 | Titik terlama hilang, grafik bergeser ke kiri |
| 3 | Pegang atau tiup sensor DHT22 | Garis naik, nilai maksimum bertambah |
| 4 | Ulangi skenario 1 dan 3 di tab MQTT | Perilaku sama, dari jalur MQTT |
| 5 | Ketuk salah satu titik | Muncul suhu dan jam pembacaan |
| 6 | Putuskan lalu hubungkan lagi | Riwayat mulai dari 0/20 |

## Pengujian unit

```bash
flutter test
```
