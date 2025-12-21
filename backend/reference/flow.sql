MYOSA Device 
   |
   |  (Publish sensor data + alerts)
   v
 MQTT Broker (Mosquitto)
   |
   |--> Flutter App (real-time MQTT alerts)
   |
   +--> FastAPI Backend (MQTT subscriber)
            |
            +--> Store data
            +--> Trigger FCM Push (fallback)
            +--> Provide REST APIs

