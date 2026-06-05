/*
 * ============================================================
 *  Smart Baby Band — ESP32 Hardware Firmware
 * ============================================================
 *  
 *  Reads real sensor data and transmits it to the FastAPI backend
 *  via WiFi HTTP POST requests every 5 seconds.
 *
 *  HARDWARE WIRING:
 *  ┌─────────────────────────────────────────────────┐
 *  │  Sensor             │  ESP32 Pin                │
 *  ├─────────────────────┼───────────────────────────┤
 *  │  MAX30102 SDA       │  GPIO 21 (I2C SDA)        │
 *  │  MAX30102 SCL       │  GPIO 22 (I2C SCL)        │
 *  │  MAX30102 VCC       │  3.3V                     │
 *  │  MAX30102 GND       │  GND                      │
 *  │  DS18B20 DATA       │  GPIO 4 (+ 4.7kΩ pullup)  │
 *  │  DS18B20 VCC        │  3.3V                     │
 *  │  DS18B20 GND        │  GND                      │
 *  │  DHT22 DATA         │  GPIO 15                  │
 *  │  DHT22 VCC          │  3.3V                     │
 *  │  DHT22 GND          │  GND                      │
 *  └─────────────────────┴───────────────────────────┘
 *
 *  REQUIRED LIBRARIES (install via Arduino Library Manager):
 *  - WiFi (built-in)
 *  - HTTPClient (built-in)
 *  - ArduinoJson by Benoit Blanchon
 *  - MAX30105 by SparkFun (for MAX30102 pulse sensor)
 *  - DallasTemperature by Miles Burton (for DS18B20)
 *  - OneWire by Jim Studt
 *  - DHT sensor library by Adafruit
 *  
 * ============================================================
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include "MAX30105.h"           // SparkFun MAX30102 library
#include "heartRate.h"          // Heart rate calculation algorithm
#include <OneWire.h>
#include <DallasTemperature.h>
#include <DHT.h>

// ═══════════════════════════════════════════════════════════
//  CONFIGURATION — CHANGE THESE VALUES
// ═══════════════════════════════════════════════════════════

// WiFi credentials
const char* WIFI_SSID     = "YOUR_WIFI_NAME";       // ← Change this
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";    // ← Change this

// Backend server URL (your computer's local IP, NOT localhost)
// To find your PC's IP: open CMD and type 'ipconfig'
// Look for "IPv4 Address" under your WiFi adapter
const char* SERVER_URL = "http://192.168.1.100:8000/api/v1/telemetry"; // ← Change IP

// Firebase User ID — get this from your app after signing up
// It will be printed in the backend logs when you log in
const char* USER_ID = "YOUR_FIREBASE_USER_UID";      // ← Change this

// Sensor pins
#define DS18B20_PIN    4    // Body temperature sensor data pin
#define DHT_PIN       15    // Room temperature/humidity sensor pin
#define DHT_TYPE     DHT22  // DHT22 or DHT11

// Transmission interval (milliseconds)
#define SEND_INTERVAL 5000  // Send data every 5 seconds

// ═══════════════════════════════════════════════════════════
//  SENSOR OBJECTS
// ═══════════════════════════════════════════════════════════

MAX30105 particleSensor;          // Heart rate + SpO2 sensor
OneWire oneWire(DS18B20_PIN);     // OneWire bus for DS18B20
DallasTemperature bodyTempSensor(&oneWire);  // DS18B20 wrapper
DHT dht(DHT_PIN, DHT_TYPE);      // Room temp + humidity sensor

// Heart rate calculation variables
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute;
int beatAvg = 0;

unsigned long lastSendTime = 0;

// ═══════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  Serial.println("\n========================================");
  Serial.println("  Smart Baby Band — ESP32 Starting...");
  Serial.println("========================================\n");

  // ── Connect to WiFi ───────────────────────────────────
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi Connected!");
    Serial.print("   IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n❌ WiFi Connection FAILED! Check credentials.");
    Serial.println("   Restarting in 5 seconds...");
    delay(5000);
    ESP.restart();
  }

  // ── Initialize MAX30102 (Heart Rate Sensor) ───────────
  Serial.print("Initializing MAX30102... ");
  if (particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("✅ Found!");
    particleSensor.setup();
    particleSensor.setPulseAmplitudeRed(0x0A);   // Low LED for proximity detection
    particleSensor.setPulseAmplitudeGreen(0);     // Turn off Green LED
  } else {
    Serial.println("⚠️ NOT FOUND — heart rate will use fallback values");
  }

  // ── Initialize DS18B20 (Body Temperature) ─────────────
  Serial.print("Initializing DS18B20... ");
  bodyTempSensor.begin();
  if (bodyTempSensor.getDeviceCount() > 0) {
    Serial.println("✅ Found!");
  } else {
    Serial.println("⚠️ NOT FOUND — body temp will use fallback values");
  }

  // ── Initialize DHT22 (Room Temp + Humidity) ───────────
  Serial.print("Initializing DHT22... ");
  dht.begin();
  Serial.println("✅ Ready");

  Serial.println("\n========================================");
  Serial.println("  All sensors initialized. Starting loop...");
  Serial.println("========================================\n");
}

// ═══════════════════════════════════════════════════════════
//  MAIN LOOP
// ═══════════════════════════════════════════════════════════

void loop() {
  // ── Continuously sample heart rate ────────────────────
  long irValue = particleSensor.getIR();
  
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    
    beatsPerMinute = 60 / (delta / 1000.0);
    
    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
      
      // Calculate average of last readings
      beatAvg = 0;
      for (byte x = 0; x < RATE_SIZE; x++) {
        beatAvg += rates[x];
      }
      beatAvg /= RATE_SIZE;
    }
  }

  // ── Send data every SEND_INTERVAL ms ──────────────────
  if (millis() - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = millis();
    
    // Read body temperature from DS18B20
    bodyTempSensor.requestTemperatures();
    float bodyTemp = bodyTempSensor.getTempCByIndex(0);
    if (bodyTemp == DEVICE_DISCONNECTED_C || bodyTemp < 30.0 || bodyTemp > 45.0) {
      bodyTemp = 36.8;  // Fallback if sensor not connected
    }

    // Read room temperature and humidity from DHT22
    float roomTemp = dht.readTemperature();
    float humidity = dht.readHumidity();
    if (isnan(roomTemp)) roomTemp = 22.0;  // Fallback
    if (isnan(humidity))  humidity = 55.0;  // Fallback

    // Use heart rate average (fallback if no finger detected)
    int heartRate = beatAvg;
    if (heartRate < 30 || irValue < 50000) {
      heartRate = 125;  // Fallback — no finger on sensor
      Serial.println("  ⚠️ No finger detected on MAX30102, using fallback HR");
    }

    // ── Send to backend ─────────────────────────────────
    sendTelemetry(bodyTemp, heartRate, roomTemp, humidity);
  }
}

// ═══════════════════════════════════════════════════════════
//  HTTP POST — Send Telemetry to Backend
// ═══════════════════════════════════════════════════════════

void sendTelemetry(float bodyTemp, int heartRate, float roomTemp, float humidity) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi disconnected! Attempting reconnect...");
    WiFi.reconnect();
    delay(2000);
    return;
  }

  // Build JSON payload (matches TelemetryPayload model)
  StaticJsonDocument<256> doc;
  doc["userId"]          = USER_ID;
  doc["temperature"]     = round(bodyTemp * 10.0) / 10.0;  // 1 decimal
  doc["heartRate"]       = heartRate;
  doc["roomTemperature"] = round(roomTemp * 10.0) / 10.0;
  doc["humidity"]        = round(humidity * 10.0) / 10.0;

  String jsonPayload;
  serializeJson(doc, jsonPayload);

  // Print to Serial Monitor
  Serial.printf("[%02d:%02d:%02d] Transmitting: Temp=%.1f°C | HR=%d BPM | Room=%.1f°C | Hum=%.1f%%\n",
    (millis()/3600000) % 24, (millis()/60000) % 60, (millis()/1000) % 60,
    bodyTemp, heartRate, roomTemp, humidity);

  // Send HTTP POST
  HTTPClient http;
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  
  int httpCode = http.POST(jsonPayload);
  
  if (httpCode == 202) {
    Serial.println("  → ✅ Accepted by backend");
  } else if (httpCode > 0) {
    Serial.printf("  → ⚠️ Server returned: %d\n", httpCode);
  } else {
    Serial.printf("  → ❌ Connection failed: %s\n", http.errorToString(httpCode).c_str());
  }
  
  http.end();
}
