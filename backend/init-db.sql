-- Create database if it doesn't exist (uses psql client meta-commands)
SELECT 'CREATE DATABASE babydb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'babydb')\gexec

-- Connect to the database and grant privileges (works whether DB was just created or already existed)
\connect babydb
GRANT ALL PRIVILEGES ON DATABASE babydb TO baby;

CREATE TABLE IF NOT EXISTS sensor_readings (
    id SERIAL PRIMARY KEY,
    device_id TEXT,
    payload JSONB,
    ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    device_id TEXT,
    alert_type TEXT,
    payload JSONB,
    ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE sensor_readings OWNER TO postgres;
ALTER TABLE alerts OWNER TO postgres;
