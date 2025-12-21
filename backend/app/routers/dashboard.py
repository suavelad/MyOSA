from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from ..database import SessionLocal
from .. import api as crud

router = APIRouter(prefix="/dashboard")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/stats")
def get_dashboard_stats(db: Session = Depends(get_db)):
    now = datetime.utcnow()
    last_24h = now - timedelta(hours=24)
    
    unique_devices = crud.get_unique_device_ids(db)
    total_devices = len(unique_devices)
    
    readings_24h = crud.get_readings_count(db, start_time=last_24h)
    alerts_24h = crud.get_alerts_count(db, start_time=last_24h)
    
    # "Active" devices could be devices that have sent data in the last 24h
    # For now, let's keep it simple and just count unique devices found in readings
    # A improved "active" check would need a more complex query
    
    return {
        "total_devices": total_devices,
        "readings_24h": readings_24h,
        "alerts_24h": alerts_24h,
        "active_devices_estimate": total_devices # Placeholder logic
    }

@router.get("/devices")
def get_known_devices(db: Session = Depends(get_db)):
    return {"devices": crud.get_unique_device_ids(db)}


@router.get("/chart/{device_id}")
def get_device_chart_data(device_id: str, period: str = "24h", metric: str = None, db: Session = Depends(get_db)):
    now = datetime.utcnow()
    start_time = now - timedelta(hours=24) # Default
    
    if period == "1h":
        start_time = now - timedelta(hours=1)
    elif period == "7d":
        start_time = now - timedelta(days=7)
    elif period == "30d":
        start_time = now - timedelta(days=30)
        
    if metric == "fall_impact":
        alerts = crud.get_alerts_history(db, device_id, alert_type="fall_impact", start_time=start_time)
        # Return list of {ts, val: 1} so we can count them
        return [
            {"ts": a.ts, "val": 1, "payload": a.payload}
            for a in alerts
        ]
        
    readings = crud.get_readings_history(db, device_id, start_time=start_time)
    
    # Return list of {ts, payload}
    return [
        {"ts": r.ts, "payload": r.payload}
        for r in readings
    ]
