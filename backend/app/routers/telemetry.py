from fastapi import APIRouter
from ..database import SessionLocal
from .. import api as  crud
from ..schema import SensorReadingOut



router = APIRouter(prefix="/telemetry")


@router.get("/latest/{device_id}", response_model=list[SensorReadingOut])
def get_latest(device_id: str, limit: int = 100):
    db = SessionLocal()
    try:
        items = crud.get_latest_readings(db, device_id, limit)
        return items
    finally:
        db.close()
