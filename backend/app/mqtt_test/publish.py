import ssl
from paho.mqtt import publish

# Your HiveMQ Cloud credentials
USERNAME="hhivemq.webclient.1766746174553"
PASSWORD='nl81%?mGy,oBgQA>7s0VL'
HOST = "3f870c7ecb2a48e6b76737cb2c13864c.s1.eu.hivemq.cloud"
PORT = 8883

# Create TLS/SSL context
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = True
ssl_context.verify_mode = ssl.CERT_REQUIRED

payload = '{"temp_threshold":39}'
publish.single(
    topic="baby/device123/config",
    payload=payload,
    hostname=HOST,
    port=PORT,
    tls=ssl_context,
    auth={
        'username': USERNAME,
        'password': PASSWORD
    }
)

print(f"Published successfully! --> {payload}")
