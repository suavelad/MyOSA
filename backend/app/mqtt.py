import os
import json
import asyncio
import ssl

from aiomqtt import Client, MqttError

from .database import SessionLocal
from . import api as crud
from decouple import config
from loguru import logger


# from .utils.fcm import send_push_to_tokens


MQTT_HOST = config("MQTT_HOST", default="mosquitto")
MQTT_PORT = config("MQTT_PORT", default=1883, cast=int)
MQTT_USER = config("MQTT_USER", default=None)
MQTT_PASS = config("MQTT_PASS", default=None)
MQTT_TLS = config("MQTT_TLS", default=False, cast=bool)
MQTT_TLS_INSECURE = config("MQTT_TLS_INSECURE", default=False, cast=bool)
MQTT_CA_CERT = config("MQTT_CA_CERT", default=None)

logger.info(f"MQTT_HOST: {MQTT_HOST}")
logger.info(f"MQTT_PORT: {MQTT_PORT}")
logger.info(f"MQTT_USER: {MQTT_USER}")
logger.info(f"MQTT_PASS: {MQTT_PASS}")


async def handle_message(topic: str, payload_str: str):
    # topic format: baby/<device_id>/sensor or baby/<device_id>/alert
    print(f"Received message on topic {topic}: {payload_str}")
    logger.info(f"Received message on topic {topic}: {payload_str}")

    parts = str(topic).split("/")
    if len(parts) < 3:
        return
    device_id = parts[1]
    typ = parts[2]


    try:
        payload = json.loads(payload_str)
    except Exception:
        payload = {"raw": payload_str}

    # Run DB operations in a separate thread to avoid blocking the event loop
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _process_message_db, device_id, typ, payload)


def _process_message_db(device_id: str, typ: str, payload: dict):
    db = SessionLocal()
    try:
        if typ == "sensor":
            from .schema import SensorReadingCreate
            item = SensorReadingCreate(device_id=device_id, payload=payload)
            crud.create_sensor_reading(db, item)
        elif typ == "alert":
            alert_type = payload.get("type", "unknown")
            crud.create_alert(db, device_id, alert_type, payload)
    except Exception as e:
        logger.error(f"DB Error processing message: {e}")
    finally:
        db.close()



def get_mqtt_client_kwargs():
    tls_context = None
    if MQTT_PORT == 8883 or MQTT_TLS:
        logger.debug("Using TLS for connection")
        tls_context = ssl.create_default_context()
        if MQTT_TLS_INSECURE:
            tls_context.check_hostname = False
            tls_context.verify_mode = ssl.CERT_NONE
            logger.warning("TLS certificate verification disabled - not recommended for production")
        else:
            tls_context.check_hostname = True
            tls_context.verify_mode = ssl.CERT_REQUIRED

    # Build connection kwargs
    client_kwargs = {
        "hostname": MQTT_HOST,
        "port": MQTT_PORT,
        "tls_context": tls_context,
    }
    
    if MQTT_USER and str(MQTT_USER).strip():
        client_kwargs["username"] = MQTT_USER
        logger.debug(f"Using username: {MQTT_USER}")
    if MQTT_PASS and str(MQTT_PASS).strip():
        client_kwargs["password"] = MQTT_PASS
        
    return client_kwargs


async def publish_message(topic: str, payload: dict):
    """
    Publishes a message to the MQTT broker.
    """
    try:
        client_kwargs = get_mqtt_client_kwargs()
        async with Client(**client_kwargs) as client:
            payload_str = json.dumps(payload)
            logger.info(f"Publishing to {topic}: {payload_str}")
            await client.publish(topic, payload=payload_str)
            logger.info(f"Successfully published to {topic}")
    except Exception as e:
        logger.error(f"Failed to publish message: {e}", exc_info=True)
        raise e



# Global semaphore to limit concurrent DB operations
_db_semaphore = asyncio.Semaphore(5)

async def mqtt_listener():
    reconnect_interval = 5
    while True:
        try:
            logger.info(f"Connecting to MQTT broker: {MQTT_HOST}:{MQTT_PORT}")
            
            client_kwargs = get_mqtt_client_kwargs()
            async with Client(**client_kwargs) as client:
 
           
                logger.info(f"✓ Connected to MQTT broker: {MQTT_HOST}:{MQTT_PORT}")
                # async with client.messages as messages:
                await client.subscribe("baby/+/sensor")
                await client.subscribe("baby/+/alert")
                logger.info("✓ Subscribed to baby/+/sensor and baby/+/alert")
                
                async for message in client.messages:
                    try:
                        topic = str(message.topic)
                        payload = message.payload.decode()
                        logger.debug(f"Raw message: {topic} -> {payload}")
                        
                        # Use semaphore to prevent flooding the thread pool/DB
                        # We spawn a waiter task that acquires semaphore then processes
                        asyncio.create_task(_bounded_handle_message(topic, payload))
                    except Exception as e:
                        logger.error(f"Error processing message: {e}", exc_info=True)
        
        except MqttError as error:
            logger.error(f"MQTT connection error: {error}", exc_info=True)
            logger.info(f"Reconnecting in {reconnect_interval} seconds...")
            await asyncio.sleep(reconnect_interval)
        except Exception as error:
            logger.error(f"Unexpected error in mqtt_listener: {error}", exc_info=True)
            logger.info(f"Reconnecting in {reconnect_interval} seconds...")
            await asyncio.sleep(reconnect_interval)

async def _bounded_handle_message(topic, payload):
    async with _db_semaphore:
        await handle_message(topic, payload)


def _process_message_db(device_id: str, typ: str, payload: dict):
    db = SessionLocal()
    try:
        if typ == "sensor":
            from .schema import SensorReadingCreate
            item = SensorReadingCreate(device_id=device_id, payload=payload)
            crud.create_sensor_reading(db, item)
        elif typ == "alert":
            # Support both 'type' and 'alert' keys for the alert name
            alert_type = payload.get("type") or payload.get("alert") or "unknown"
            crud.create_alert(db, device_id, alert_type, payload)
    except Exception as e:
        logger.error(f"DB Error processing message: {e}")
    finally:
        db.close()
