from sqlalchemy.orm import Session
from . import models, schema
from datetime import datetime


def create_sensor_reading(db: Session, reading: schema.SensorReadingCreate):
    db_item = models.SensorReading(device_id=reading.device_id, payload=reading.payload)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


def create_alert(db: Session, device_id: str, alert_type: str, payload: dict):
    db_item = models.Alert(device_id=device_id, alert_type=alert_type, payload=payload)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


def get_latest_readings(db: Session, device_id: str, limit: int = 100):
    return db.query(models.SensorReading).filter(models.SensorReading.device_id == device_id).order_by(models.SensorReading.ts.desc()).limit(limit).all()


    return db.query(models.Alert).filter(models.Alert.device_id == device_id).order_by(models.Alert.ts.desc()).limit(limit).all()


def get_unique_device_ids(db: Session):
    # This might be slow on large datasets, but fine for MVP
    return [r[0] for r in db.query(models.SensorReading.device_id).distinct().all()]


def get_readings_count(db: Session, start_time: datetime = None):
    query = db.query(models.SensorReading)
    if start_time:
        query = query.filter(models.SensorReading.ts >= start_time)
    return query.count()


def get_alerts_count(db: Session, start_time: datetime = None):
    query = db.query(models.Alert)
    if start_time:
        query = query.filter(models.Alert.ts >= start_time)
    return query.count()


def get_readings_history(db: Session, device_id: str, start_time: datetime = None, end_time: datetime = None, limit: int = 2000):
    query = db.query(models.SensorReading).filter(models.SensorReading.device_id == device_id)
    if start_time:
        query = query.filter(models.SensorReading.ts >= start_time)
    if end_time:
        query = query.filter(models.SensorReading.ts <= end_time)
    return query.order_by(models.SensorReading.ts.asc()).limit(limit).all()


def get_alerts_history(db: Session, device_id: str, alert_type: str = None, start_time: datetime = None, end_time: datetime = None, limit: int = 2000):
    query = db.query(models.Alert).filter(models.Alert.device_id == device_id)
    if alert_type:
        query = query.filter(models.Alert.alert_type == alert_type)
    if start_time:
        query = query.filter(models.Alert.ts >= start_time)
    if end_time:
        query = query.filter(models.Alert.ts <= end_time)
    return query.order_by(models.Alert.ts.asc()).limit(limit).all()
