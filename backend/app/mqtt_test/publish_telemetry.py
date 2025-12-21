import ssl
import json
import time
import random
from paho.mqtt import publish

# HiveMQ Cloud credentials
USERNAME="hivemq.webclient.1766015226299"
PASSWORD='nd<N38;54XVeSAswcH,!'
HOST = "3f870c7ecb2a48e6b76737cb2c13864c.s1.eu.hivemq.cloud"
PORT = 8883

# Device ID
DEVICE_ID = "device123"

# Create TLS/SSL context
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = True
ssl_context.verify_mode = ssl.CERT_REQUIRED

print(f"Starting telemetry simulation for {DEVICE_ID}...")
print("Press Ctrl+C to stop.")

try:
    while True:
        # Simulate data
        temp = round(random.uniform(20.0, 25.0), 1)
        humidity = round(random.uniform(40.0, 60.0), 1)
        sound = round(random.uniform(30.0, 50.0), 1)
        
        payload = {
            "temperature": temp,
            "humidity": humidity,
            "sound": sound,
            "battery": 95
        }
        
        publish.single(
            topic=f"baby/{DEVICE_ID}/sensor",
            payload=json.dumps(payload),
            hostname=HOST,
            port=PORT,
            tls=ssl_context,
            auth={
                'username': USERNAME,
                'password': PASSWORD
            }
        )
        
        print(f"Published: {payload}")
        time.sleep(2)

except KeyboardInterrupt:
    print("\nSimulation stopped.")
