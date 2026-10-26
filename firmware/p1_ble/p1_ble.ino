// Praktikum 1 (modul 5.3): ESP32 as BLE GATT server.
// One service, two characteristics: LED (read/write) and sensor (read/notify).
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DHT.h>

// LED: GPIO 26 as in the module. The ESP32-S3 uses GPIO 5 instead, because its
// GPIO 26-32 belong to the flash/PSRAM. Chosen automatically when compiling.
#if CONFIG_IDF_TARGET_ESP32S3
#define LED_PIN 5
#else
#define LED_PIN 26
#endif
#define DHT_PIN 4
#define DHT_TYPE DHT22 

#define SERVICE_UUID "12345678-1234-5678-1234-56789abcdef0"
#define LED_UUID     "12345678-1234-5678-1234-56789abcdef1"
#define SENSOR_UUID  "12345678-1234-5678-1234-56789abcdef2"

DHT dht(DHT_PIN, DHT_TYPE);
BLECharacteristic *sensorChar;
volatile bool deviceConnected = false;
unsigned long lastSend = 0;

class ServerCb : public BLEServerCallbacks {
  void onConnect(BLEServer *s) {
    deviceConnected = true;
    Serial.println("BLE: client terhubung");
  }
  void onDisconnect(BLEServer *s) {
    deviceConnected = false;
    Serial.println("BLE: client terputus");
    BLEDevice::startAdvertising();  // agar bisa dihubungi lagi
  }
};

class LedCb : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) {
    auto v = c->getValue();
    if (v.length() > 0) {
      bool on = (v[0] == 1 || v[0] == '1');
      digitalWrite(LED_PIN, on ? HIGH : LOW);
      Serial.printf("LED -> %s\n", on ? "ON" : "OFF");
    }
  }
};

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  dht.begin();

  BLEDevice::init("ESP32-OIT-KEL1");
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCb());

  BLEService *service = server->createService(SERVICE_UUID);

  BLECharacteristic *ledChar = service->createCharacteristic(
      LED_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  ledChar->setCallbacks(new LedCb());

  sensorChar = service->createCharacteristic(
      SENSOR_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  sensorChar->addDescriptor(new BLE2902());

  service->start();
  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("BLE advertising: ESP32-OIT-KEL1");
}

void loop() {
  if (deviceConnected && millis() - lastSend >= 2000) {
    lastSend = millis();
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t) && !isnan(h)) {
      char buf[24];
      snprintf(buf, sizeof(buf), "%.1f;%.1f", t, h);
      sensorChar->setValue((uint8_t *)buf, strlen(buf));
      sensorChar->notify();
      Serial.printf("Notify: %s\n", buf);
    }
  }
}
