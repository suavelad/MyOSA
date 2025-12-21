from fastapi import APIRouter
from ..database import SessionLocal
from .. import  api as crud
from ..schema import AlertOut


router = APIRouter(prefix="/alerts")


@router.get("/{device_id}", response_model=list[AlertOut])
def get_alerts(device_id: str, limit: int = 50):
    db = SessionLocal()
    try:
        items = crud.get_latest_alerts(db, device_id, limit)
        return items
    finally:
        db.close()
