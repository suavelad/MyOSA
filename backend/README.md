# FastAPI Baby Monitoring Backend


This project implements a FastAPI backend to ingest MQTT messages from MYOSA devices, persist telemetry and alerts to PostgreSQL, and send fallback push notifications via FCM.


Features:
- Async MQTT consumer using `asyncio-mqtt`
- REST APIs to fetch telemetry and alerts
- PostgreSQL storage via SQLAlchemy
- FCM fallback push using `firebase-admin`
- Docker + docker-compose for local dev (Mosquitto + Postgres + FastAPI)


## Quickstart
1. Copy `.env.example` to `.env` and edit values.
2. Build and start services:


```bash
docker-compose up --build
