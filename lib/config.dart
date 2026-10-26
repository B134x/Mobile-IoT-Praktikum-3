/// Settings shared by the BLE page, the MQTT page and the firmware.
///
/// They must match the `#define`s and constants in `firmware/`. The broker is
/// public, so [kelompok] must be a name no other group uses.
library;

const kelompok = 'kel1';

// BLE GATT structure (modul 5.2).
const serviceUuid = '12345678-1234-5678-1234-56789abcdef0';
const ledUuid = '12345678-1234-5678-1234-56789abcdef1';
const sensorUuid = '12345678-1234-5678-1234-56789abcdef2';

// MQTT broker and topics (modul 6.1).
const host = 'broker.emqx.io';
const port = 1883;
const tSensor = 'polnes/oit/$kelompok/sensor';
const tLed = 'polnes/oit/$kelompok/led';
const tLedState = 'polnes/oit/$kelompok/led/state';
const tStatus = 'polnes/oit/$kelompok/status';

/// Tugas 3: how many readings each temperature chart keeps.
const historyLength = 20;
