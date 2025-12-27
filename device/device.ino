#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <MQTT.h>
#include <Wire.h>
#include <AccelAndGyro.h>
#include <BarometricPressure.h>
#include <ArduinoJson.h>
#include <Preferences.h>


/* =========================================================
   ALERT COOLDOWN (CHANGE HERE)
   ========================================================= */
const unsigned long ALERT_COOLDOWN = 2 * 60 * 1000UL; // 2 minutes

unsigned long lastFallAlertTime = 0;
unsigned long lastTempAlertTime = 0;


/* =========================================================
   OBJECTS
   ========================================================= */
Preferences prefs;
AccelAndGyro Ag;
BarometricPressure Pr(ULTRA_HIGH_RESOLUTION);

WiFiClientSecure net;
MQTTClient client(512);

/* =========================================================
   WIFI / MQTT
   ========================================================= */
const char* ssid = "Canal33333-2G";
const char* password = "1234567890";

const char* mqtt_server = "3f870c7ecb2a48e6b76737cb2c13864c.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "hivemq.webclient.1766833151037";
const char* mqtt_pass = "f7TEHZ8>Ld#vy,R6j5%e";

#define DEVICE_ID "device123"
#define TOPIC_SENSOR  "baby/" DEVICE_ID "/sensor"
#define TOPIC_ALERT   "baby/" DEVICE_ID "/alert"
#define TOPIC_COMMAND "baby/" DEVICE_ID "/config"

/* =========================================================
   BABY FALL THRESHOLDS (30cm+)
   ========================================================= */
const float IMPACT_G       = 1.1f;
const float IMPACT_SLOPE_G = 0.6f;
const float GYRO_SPIKE     = 70.0f;
const unsigned long FALL_COOLDOWN = 5000;

/* =========================================================
   FILTER
   ========================================================= */
const float ALPHA = 0.25f;

/* =========================================================
   VARIABLES
   ========================================================= */
float ax_f = 0, ay_f = 0, az_f = 0;
float gravityX = 0, gravityY = 0, gravityZ = 0;

float lastNetAcc = 0;
unsigned long lastFallTime = 0;

float tempThreshold = 36.0;
bool tempAlertSent = false;

unsigned long sensorMillis = 0;
unsigned long publishMillis = 0;
const unsigned long SENSOR_INTERVAL  = 20;
const unsigned long PUBLISH_INTERVAL = 15000;

/* =========================================================
   HELPERS
   ========================================================= */
float magnitude(float x, float y, float z) {
  return sqrt(x*x + y*y + z*z);
}

/* =========================================================
   MQTT
   ========================================================= */
void wifiConnect() {
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) delay(300);
}

void mqttConnect() {
  net.setInsecure();
  client.begin(mqtt_server, mqtt_port, net);
  while (!client.connect("esp32-baby", mqtt_user, mqtt_pass)) delay(500);
  client.subscribe(TOPIC_COMMAND);
}

void publishMessage(const char* topic, const char* payload) {
  if (!client.connected()) mqttConnect();
  client.publish(topic, payload);
}

void messageReceived(String& topic, String& payload) {
  StaticJsonDocument<128> doc;
  if (deserializeJson(doc, payload) == DeserializationError::Ok) {
    if (doc.containsKey("temp_threshold")) {
      tempThreshold = doc["temp_threshold"];
      prefs.putFloat("temp_th", tempThreshold);
    }
  }
}

/* =========================================================
   SETUP
   ========================================================= */
void setup() {
  Serial.begin(115200);
  Wire.begin();

  prefs.begin("config", false);
  tempThreshold = prefs.getFloat("temp_th", tempThreshold);
  tempAlertSent = false;  // FORCE RESET

  wifiConnect();
  client.onMessage(messageReceived);
  mqttConnect();

  while (!Ag.begin()) delay(200);
  while (!Pr.begin()) delay(200);

  /* Gravity calibration */
  float sx=0, sy=0, sz=0;
  for (int i=0;i<30;i++) {
    sx += Ag.getAccelX();
    sy += Ag.getAccelY();
    sz += Ag.getAccelZ();
    delay(20);
  }
  gravityX = sx/30;
  gravityY = sy/30;
  gravityZ = sz/30;

  Serial.println("✅ Baby fall & temperature system READY");
}

/* =========================================================
   LOOP
   ========================================================= */
void loop() {
  client.loop();
  unsigned long now = millis();
  if (now - sensorMillis < SENSOR_INTERVAL) return;
  sensorMillis = now;

  /* -------- RAW SENSOR -------- */
  float ax = Ag.getAccelX();
  float ay = Ag.getAccelY();
  float az = Ag.getAccelZ();

  float gx = Ag.getGyroX();
  float gy = Ag.getGyroY();
  float gz = Ag.getGyroZ();

  float tx = Ag.getTiltX();
  float ty = Ag.getTiltY();
  float tz = Ag.getTiltZ();
  
  float tempC = Ag.getTempC();

  /* -------- FILTER -------- */
  ax_f = ALPHA * ax + (1 - ALPHA) * ax_f;
  ay_f = ALPHA * ay + (1 - ALPHA) * ay_f;
  az_f = ALPHA * az + (1 - ALPHA) * az_f;

  /* -------- MAGNITUDES -------- */
  float netAcc = magnitude(
    ax - gravityX,
    ay - gravityY,
    az - gravityZ
  );

  float gyroMag = magnitude(gx, gy, gz);
  float accSlope = netAcc - lastNetAcc;
  lastNetAcc = netAcc;

  /* =====================================================
     🚨 BABY FALL DETECTION (REAL-TIME)
     ===================================================== */
  if (
    netAcc > IMPACT_G &&
    accSlope > IMPACT_SLOPE_G &&
    gyroMag > GYRO_SPIKE &&
    (now - lastFallTime) > FALL_COOLDOWN
  ) {
    lastFallTime = now;

    StaticJsonDocument<128> alert;
    alert["alert"] = "fall_impact";
    alert["status"] = true;
    alert["severity_score"] = netAcc * gyroMag;

    char buf[128];
    serializeJson(alert, buf);
    publishMessage(TOPIC_ALERT, buf);

    Serial.println("🚨 BABY FALL ALERT SENT");
  }

  /* =====================================================
     🌡 TEMPERATURE ALERT (FIXED)
     ===================================================== */
  if (tempC >= tempThreshold && !tempAlertSent) {
    StaticJsonDocument<128> alert;
    alert["alert"] = "high_temperature";
    alert["status"] = true;
    alert["temperature"] = tempC;

    char buf[128];
    serializeJson(alert, buf);
    publishMessage(TOPIC_ALERT, buf);

    tempAlertSent = true;
    Serial.println("🌡 TEMPERATURE ALERT SENT");
  }

  if (tempC < tempThreshold - 0.5f) {
    tempAlertSent = false;
  }

  /* ---------------- TELEMETRY ---------------- */
  if (now - publishMillis >= PUBLISH_INTERVAL) {
    publishMillis = now;

    StaticJsonDocument<512> data;

    JsonObject acc = data.createNestedObject("acc");
    acc["x"] = ax_f;
    acc["y"] = ay_f;
    acc["z"] = az_f;
    acc["net"] = netAcc;

    JsonObject gyro = data.createNestedObject("gyro");
    gyro["x"] = gx;
    gyro["y"] = gy;
    gyro["z"] = gz;
    gyro["mag"] = gyroMag;

    JsonObject tilt = data.createNestedObject("tilt");
    tilt["x"] = tx;
    tilt["y"] = ty;
    tilt["z"] = tz;

    data["temp"] = tempC;
    data["thresTemp"] = tempThreshold;

    char buf[512];
    serializeJson(data, buf);
    publishMessage(TOPIC_SENSOR, buf);
  }
}
