# Smart Baby Band - FastAPI Backend

This is the asynchronous FastAPI backend ingestion server designed to connect your **Smart Baby Band wearable hardware** (IoT device) and synchronize biological and environmental telemetry with your **Flutter mobile application** via Google Cloud Firestore and Firebase Cloud Messaging (FCM).

---

## 🚀 Features
- **High-Performance IoT Ingestion**: Processes telemetry payloads rapidly using asynchronous background tasks.
- **Biometric Analytics**: Infers sleep states and categorizes infant cries.
- **Dual Runtime Support**: Runs in **Live mode** (connected to Firestore and FCM) or **Mock mode** (prints state outputs to console, letting you run immediately without credentials).
- **FCM Push Notification engine**: Sends immediate critical alerts (Heart rate > 150 BPM, Temp > 37.5°C) to the parent's device.
- **Interactive OpenAPI Documentation**: Built-in Swagger UI sandbox.

---

## 🛠️ Tech Stack
- **FastAPI / Uvicorn** (Asynchronous ASGI server layer)
- **Firebase Admin SDK** (Firestore connectivity and FCM push notifications)
- **Pydantic** (Biometric telemetry schemas and payload type validations)
- **Python-dotenv** (Local environment configurations)

---

## 📦 Installation & Setup

### 1. Prerequisite: Install Python
Ensure Python 3.8 or higher is installed on your local machine.

### 2. Prepare Virtual Environment
Open your terminal in the `backend` directory and configure a virtual environment:
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows (Command Prompt):
venv\Scripts\activate
# On Windows (PowerShell):
.\venv\Scripts\activate
# On macOS / Linux:
source venv/bin/activate
```

### 3. Install Dependencies
Run the following pip install:
```bash
pip install -r requirements.txt
```

---

## ⚙️ Configuration (Live vs Mock)

### Running in Mock Demonstration Mode (Default)
By default, the server runs in **Mock Mode** if no service account JSON is supplied.
- Telemetry is successfully accepted.
- Operations that would write to Firestore or send push alerts are instead printed cleanly inside the terminal logs.
- This lets you sandbox the entire backend flow instantly.

### Running in Live Mode
To connect the backend to your live Firebase Cloud project:
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Navigate to **Project Settings** > **Service Accounts**.
3. Click **Generate New Private Key** and download the JSON file.
4. Move this JSON file inside the `backend` folder and name it `firebase-credentials.json` (or place it anywhere and update `.env`).
5. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
6. Open `.env` and verify `FIREBASE_CREDENTIALS_PATH` is set correctly:
   ```env
   FIREBASE_CREDENTIALS_PATH=app/firebase-credentials.json
   ```

---

## ⚡ Running the Server

Start the local server using Uvicorn:
```bash
# Run server under reload mode (auto-reboots on file saves)
python app/main.py
```
Or use uvicorn directly:
```bash
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

---

## 🧪 Testing & Ingestion

### 1. Interactive Swagger Sandboxing
With the server running, open your web browser to:
👉 **[http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)**

You will see the interactive Swagger UI console. You can click on the `POST /api/v1/telemetry` or `POST /api/v1/cry-test` endpoints, click **Try it out**, fill in a test payload, and hit **Execute** to trigger the API.

### 2. Running the Wearable Band Simulator
To mimic a physical baby band broadcasting metrics:
1. Open a new terminal tab and activate the virtual environment (`venv\Scripts\activate`).
2. Open `mock_hardware.py` and replace `TEST_USER_ID = "parent_auth_uid_12345"` with your actual parent user UID (which is created during registration/login in the mobile app, or copy it from your Firestore console).
3. Execute the mock hardware simulator client:
   ```bash
   python mock_hardware.py
   ```
This script will stream changing body temperatures, heart rates, and ambient room settings to the local backend every 5 seconds, allowing you to test real-time Firestore synchronization and threshold checks.
