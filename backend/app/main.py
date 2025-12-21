import asyncio
from fastapi import FastAPI
from .database import engine, Base
from . import  mqtt as  mqtt_client
from .routers import devices, telemetry, alerts, dashboard


Base.metadata.create_all(bind=engine)


app = FastAPI(title="Baby Monitor Backend")


app.include_router(devices.router)
app.include_router(telemetry.router)
app.include_router(alerts.router)
app.include_router(dashboard.router)


@app.on_event("startup")
async def startup_event():
# start MQTT listener in background
    asyncio.create_task(mqtt_client.mqtt_listener())


@app.get("/health")
def health():
    return {"status": "ok"}
