# MyOSA Baby Monitor System Documentation

## 1. Project Overview

**MyOSA DIY** is a smart baby monitor system designed to provide real-time monitoring and safety alerts for infants. The system integrates an embedded device (ESP32-based), a robust backend API, and a cross-platform mobile application (Flutter).

The primary goal of the system is to detect potential hazards such as falls or high temperatures and instantly notify parents or guardians via the mobile app. It also provides a dashboard for visualizing historical and real-time sensor data.

### System Architecture
The system consists of three main components:
1.  **Device (Firmware)**: An ESP32 microcontroller equipped with sensors (Accelerometer, Gyroscope, Barometer) to collect data and detect events. It communicates via MQTT.
2.  **Backend (Server)**: A Python FastAPI application that processes MQTT messages, manages the database, and exposes a REST API for the mobile app.
3.  **Mobile App (Client)**: A Flutter application that allows users to view sensor data, receive alerts, and configure the device.

---

## 2. Key Features

### Real-Time Monitoring
-   **Motion Tracking**: Continuous stream of Accelerometer (X, Y, Z), Gyroscope, and Tilt data.
-   **Environmental Sensing**: Real-time temperature and barometric pressure (altitude) readings.
-   **Live Dashboard**: Visual charts and numeric displays in the mobile app.

### Advanced Alerting System
-   **Fall Detection**: Intelligent algorithm detecting free-fall phases followed by impact. It calculates a severity score based on multiple factors (acceleration, rotation, vertical speed).
-   **Temperature Alerts**: Automatic alerts when the ambient temperature exceeds a user-defined threshold.
-   **Push Notifications**: (Planned/Implemented) Immediate notification delivery to the mobile app.

### Remote Configuration
-   **Threshold Management**: Users can adjust sensitivity settings, such as the high-temperature threshold, directly from the mobile app. These changes are synchronized with the device via MQTT.

### Data Analysis
-   **Historical Data**: Storage of sensor readings and alert history in a PostgreSQL database (or compatible SQL DB).
-   **Visualization**: Interactive charts for trend analysis over time.

---

## 3. Technology Stack

### Firmware (Device)
-   **Hardware**: ESP32 Microcontroller
-   **Language**: C++ (Arduino Framework)
-   **Communication Protocol**: MQTT (Secure SSL/TLS)
-   **Key Libraries**:
    -   `WiFiClientSecure` & `MQTT` for connectivity.
    -   `ArduinoJson` for data serialization.
    -   `AccelAndGyro` & `BarometricPressure` for sensor interfacing.

### Backend
-   **Language**: Python 3.9+
-   **Web Framework**: FastAPI
-   **Database ORM**: SQLAlchemy
-   **Database**: PostgreSQL
-   **Message Broker**: Mosquitto / HiveMQ (Cloud)
-   **Async Task Queue**: `asyncio` for background MQTT listening.
-   **Infrastructure**: Docker & Docker Compose.

### Mobile Application
-   **Framework**: Flutter (Dart)
-   **Architecture**: Provider State Management
-   **Platforms**: iOS, Android
-   **Key Packages**:
    -   `mqtt_client`: For messaging.
    -   `fl_chart`: For data visualization.
    -   `http`: For REST API communication.
    -   `provider`: For state management.

---

## 4. Usage Instructions

### Prerequisites
-   **Docker Desktop** installed on your machine.
-   **Flutter SDK** installed for mobile development.
-   **ESP32 Development Board** with appropriate sensors connected.

### Backend Setup
1.  Navigate to the `backend` directory:
    ```bash
    cd backend
    ```
2.  Create a `.env` file based on `.env.example` and configure your database and MQTT credentials.
3.  Start the services using Docker Compose:
    ```bash
    docker compose up --build
    ```
    The backend API will be available at `http://localhost:8001` (or port defined in `docker-compose.yaml`).

### Mobile App Setup
1.  Navigate to the `mobile` directory:
    ```bash
    cd mobile
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the application on a connected device or emulator:
    ```bash
    flutter run
    ```
    *Note: Ensure the mobile device is on the same network or can access the backend API IP.*

### Device Setup
1.  Open `device/device.ino` in the Arduino IDE or PlatformIO.
2.  Update the `ssid`, `password`, and MQTT credentials in the code.
3.  Flash the firmware to your ESP32 board.
4.  Open the Serial Monitor (Baud Rate: 115200) to verify connection and sensor readings.


