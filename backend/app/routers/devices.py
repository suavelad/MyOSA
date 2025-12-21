from fastapi import APIRouter, Depends, HTTPException
from ..database import SessionLocal
from .. import  api as crud
from ..schema import SensorReadingOut


router = APIRouter(prefix="/devices")


@router.get("/{device_id}/telemetry", response_model=list[SensorReadingOut])
def get_telemetry(device_id: str, limit: int = 100):
    db = SessionLocal()
    try:
        items = crud.get_latest_readings(db, device_id, limit)
        return items
    finally:
        db.close()


@router.post("/{device_id}/config")
async def push_config(device_id: str, config: dict):
    from .. import mqtt
    
    topic = f"baby/{device_id}/config"
    await mqtt.publish_message(topic, config)
    return {"status": "success", "message": "Config pushed to device", "topic": topic}
