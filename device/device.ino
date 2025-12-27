#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <MQTT.h>
#include <Wire.h>
#include <AccelAndGyro.h>
#include <BarometricPressure.h>
#include <ArduinoJson.h>
#include <Preferences.h>

Preferences prefs;

// ---------- SENSOR OBJECTS ----------
AccelAndGyro Ag;
BarometricPressure Pr(ULTRA_HIGH_RESOLUTION);


// WiFi credentials
const char* ssid     = "Testing-2G";
const char* password = "1234567890";

// HiveMQ Cloud credentials
const char* mqtt_server   = "3f870c7ecb2a48e6b76737cb2c13864c.s1.eu.hivemq.cloud";
const int   mqtt_port     = 8883;
const char* mqtt_user     = "hivemq.webclient.1766746174553";
const char* mqtt_pass     = "!tL29;S7p#dffdd<";


// Topics
#define DEVICE_ID "device123"
#define TOPIC_SENSOR "baby/" DEVICE_ID "/sensor"
#define TOPIC_ALERT "baby/" DEVICE_ID "/alert"
#define TOPIC_COMMAND "baby/" DEVICE_ID "/config"

WiFiClientSecure net;
MQTTClient client(512);

// ---------- FALL DETECTION PARAMETERS ----------
float accThreshold = 2.5;             // g-force impact threshold
float freeFallThreshold = 0.3;        // g-force free fall
unsigned long inactivityTime = 3000;  // ms

float previousAltitude = 0;
unsigned long previousMillis = 0;

float tempThreshold = 23.0;   // default fever threshold (°C)
bool tempAlertSent = false;   // avoid alert spam

// ---------- ALERT STATE MACHINE ----------
enum FallState { IDLE,
                 FALL_DETECTED,
                 ALERT_SENT };

FallState fallState = IDLE;
unsigned long impactMillis = 0;

// ---------- TIMERS ----------
unsigned long sensorMillis = 0;
const unsigned long sensorInterval = 50;  // 50 ms = 20 Hz
unsigned long publishMillis = 0;
const unsigned long publishInterval = 1000;  // 1 Hz MQTT

// ---------- HELPER FUNCTIONS ----------
float accMagnitude(float x, float y, float z) {
  return sqrt(x * x + y * y + z * z);
}

float computeSeverity(float accMag, float gyroMag, float tiltChange, float verticalSpeed) {
  // weighted sum: acceleration 50%, gyro 25%, tilt 15%, vertical speed 10%
  return accMag * 0.5 + gyroMag * 0.25 + tiltChange * 0.15 + verticalSpeed * 0.1;
}

bool checkImpact(float accMag) {
  return accMag > accThreshold;
}

bool checkFreeFall(float accMag) {
  return accMag < freeFallThreshold;
}

// ---------- MQTT ----------
void wifiConnect() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println("\nWiFi Connected!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}

void mqttConnect() {
  net.setInsecure();
  client.begin(mqtt_server, mqtt_port, net);
  while (!client.connect("esp32-client", mqtt_user, mqtt_pass)) {
    Serial.print(".");
    delay(1000);
  }
  Serial.println("\nMQTT Connected!");
  client.subscribe(TOPIC_COMMAND);
}

void publishSensorData(const char* payload, bool alert = false) {
  if (client.connected() && payload && strlen(payload) > 0) {
    if (alert) {
      client.publish(TOPIC_ALERT, payload);
    } else {
      client.publish(TOPIC_SENSOR, payload);
    }
    Serial.println("Published Successfully");
  }
}

void messageReceived(String &topic, String &payload) {
  Serial.println("Incoming: " + topic + " | " + payload);

  if (topic == TOPIC_COMMAND) {
    StaticJsonDocument<128> doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err) {
      Serial.println("Invalid command JSON");
      return;
    }

    // Example payload: { "temp_threshold": 37.5 }
    if (doc.containsKey("temp_threshold")) {
      tempThreshold = doc["temp_threshold"];
      prefs.putFloat("temp_th", tempThreshold);
      Serial.print("Updated temp threshold: ");
      Serial.println(tempThreshold);
      StaticJsonDocument<128> ack;
      ack["config"] = "temp_threshold_updated";
      ack["value"] = tempThreshold;
      char buf[128];
      serializeJson(ack, buf);
      publishSensorData(buf, false);
    }
  }
}
 

// ---------- SETUP ----------
void setup() {
  Serial.begin(115200);
  Wire.begin();
  Wire.setClock(100000);

  wifiConnect();
  client.onMessage(messageReceived);
  mqttConnect();

  prefs.begin("config", false);   // namespace = "config"

  tempThreshold = prefs.getFloat("temp_th", tempThreshold);

  Serial.print("Loaded temp threshold: ");
  Serial.println(tempThreshold);

  // Initialize sensors
  while (!Ag.begin()) {
    Serial.println("Waiting for Accel/Gyro...");
    delay(500);
  }
  Serial.println("Accel/Gyro connected");

  while (!Pr.begin()) {
    Serial.println("Waiting for Barometer...");
    delay(500);
  }
  Serial.println("Barometer connected");

  previousAltitude = Pr.getAltitude(SEA_LEVEL_AVG_PRESSURE);
  previousMillis = millis();
}

// ---------- LOOP ----------
void loop() {
  client.loop();
  unsigned long now = millis();

  // Sensor reading at high frequency
  if (now - sensorMillis >= sensorInterval) {
    sensorMillis = now;

    // --- Read accelerometer/gyro/tilt ---
    float accX = Ag.getAccelX();
    float accY = Ag.getAccelY();
    float accZ = Ag.getAccelZ();
    float gyroX = Ag.getGyroX();
    float gyroY = Ag.getGyroY();
    float gyroZ = Ag.getGyroZ();
    float tiltX = Ag.getTiltX();
    float tiltY = Ag.getTiltY();
    float tiltZ = Ag.getTiltZ();
    float tempC = Ag.getTempC();

    float accMag = accMagnitude(accX, accY, accZ);
    float gyroMag = accMagnitude(gyroX, gyroY, gyroZ);
    float tiltChange = abs(tiltX) + abs(tiltY);

    // --- Read barometer ---
    float currentAltitude = Pr.getAltitude(SEA_LEVEL_AVG_PRESSURE);
    float deltaTime = (now - previousMillis) / 1000.0;
    float verticalSpeed = 0;
    if (deltaTime > 0) {
      verticalSpeed = (previousAltitude - currentAltitude) / deltaTime;
      previousAltitude = currentAltitude;
      previousMillis = now;
    }

    // --- Fall Detection State Machine ---
    switch (fallState) {
      case IDLE:
        if (checkFreeFall(accMag)) {
          Serial.println("Free fall detected, waiting for impact...");
        }
        if (checkImpact(accMag)) {
          fallState = FALL_DETECTED;
          impactMillis = now;
          Serial.println("Impact detected! Monitoring inactivity...");
        }
        break;

      case FALL_DETECTED:
        if (now - impactMillis > inactivityTime) {
          float severity = computeSeverity(accMag, gyroMag, tiltChange, verticalSpeed);
          Serial.print("Fall alert! Severity: ");
          Serial.println(severity);

          // Send alert payload
          StaticJsonDocument<384> doc;
          doc["alert"] = "fall_impact";
          doc["status"] = true;
          doc["severity_score"] = severity;
          char buf[384];
          serializeJson(doc, buf);
          publishSensorData(buf, true);
          fallState = ALERT_SENT;
        }
        break;

      case ALERT_SENT:
        // Wait for manual reset or recovery
        break;
    }

    // --- Event-driven publishing ---
    if (now - publishMillis >= publishInterval) {
      publishMillis = now;

      // Sensor data payload
      StaticJsonDocument<384> doc;
      doc["sensor"] = "accGyro";
      doc["temp"] = tempC;
      doc["thresholdTemp"] = tempThreshold;


      // ---------- TEMPERATURE ALERT ----------
      if (tempC >= tempThreshold && !tempAlertSent) {
        Serial.println("Temperature threshold exceeded!");

        StaticJsonDocument<256> doc;
        doc["alert"] = "high_temperature";
        doc["status"] = true;
        doc["temperature"] = tempC;
        doc["threshold"] = tempThreshold;

        char buf[256];
        serializeJson(doc, buf);
        publishSensorData(buf, true);
        tempAlertSent = true;   // prevent repeated alerts
      }

      // Reset alert if temperature returns to normal
      if (tempC < tempThreshold - 0.5) {
        tempAlertSent = false;
      }

      JsonObject acc = doc.createNestedObject("acc");
      acc["x"] = accX;
      acc["y"] = accY;
      acc["z"] = accZ;

      JsonObject gyro = doc.createNestedObject("gyro");
      gyro["x"] = gyroX;
      gyro["y"] = gyroY;
      gyro["z"] = gyroZ;

      JsonObject tilt = doc.createNestedObject("tilt");
      tilt["x"] = tiltX;
      tilt["y"] = tiltY;
      tilt["z"] = tiltZ;

      JsonObject baro = doc.createNestedObject("barometer");
      baro["altitude"] = currentAltitude;
      baro["vertical_speed"] = verticalSpeed;

      char buf[384];
      serializeJson(doc, buf);
      publishSensorData(buf);
      delay(10000u); // for testing to delay the data loading
    }
  }
}
