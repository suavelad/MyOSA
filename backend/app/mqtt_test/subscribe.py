import ssl
import paho.mqtt.client as mqtt

USERNAME="hivemq.webclient.1765472845113"
PASSWORD='23hRL#Qg98qB;%Ca$Akm'
HOST = "3f870c7ecb2a48e6b76737cb2c13864c.s1.eu.hivemq.cloud"
PORT = 8883

def on_connect(client, userdata, flags, rc):
    print("Connected:", rc)
    client.subscribe("baby/+/sensor")

def on_message(client, userdata, msg):
    print(f"{msg.topic}: {msg.payload.decode()}")

ssl_context = ssl.create_default_context()

client = mqtt.Client()
client.username_pw_set(USERNAME, PASSWORD)
client.tls_set_context(ssl_context)

client.on_connect = on_connect
client.on_message = on_message

client.connect(HOST, PORT)
client.loop_forever()
