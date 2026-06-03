import uvicorn
from fastapi import FastAPI, BackgroundTasks, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.models import TelemetryPayload, AlertOverridePayload, UserPreferencesPayload
from app.services.firebase_service import firebase_service
from app.services.ml_service import ml_service

# Initialize FastAPI Application
app = FastAPI(
    title="Smart Baby Band Backend API",
    description="Asynchronous ingestion gateway for real-time infant sensor analytics and FCM alerts.",
    version="1.0.0",
    debug=settings.DEBUG
)

# Add CORS Middleware to support development testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def evaluate_and_alert(user_id: str, heart_rate: int, temperature: float):
    """Checks parameters against critical limits and dispatches FCM messages if exceeded."""
    
    # 1. Critical High Heart Rate (threshold configured in settings as 150 BPM)
    if heart_rate > 150:
        firebase_service.send_push_alert(
            user_id=user_id,
            title="Emergency Alert",
            body=f"Heart rate is critically elevated at {heart_rate} BPM!",
            data_payload={
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "route": "/notifications",
                "metric": "Heart rate",
                "value": f"{heart_rate} bpm",
                "status": "Too High"
            }
        )
    
    # 2. Critical High Temperature (threshold configured as 37.5°C)
    if temperature > 37.5:
        firebase_service.send_push_alert(
            user_id=user_id,
            title="Fever Alert",
            body=f"High temperature detected at {temperature}°C!",
            data_payload={
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                "route": "/notifications",
                "metric": "Temperature",
                "value": f"{temperature}°C",
                "status": "Too High"
            }
        )

def get_temp_status(temp: float) -> str:
    """Helper mapping exactly to the status calculations in Flutter's tempraturehistory.dart."""
    if temp < 36.5:
        return "Low"
    elif temp <= 37.0:
        return "Normal"
    elif temp <= 37.5:
        return "High"
    return "Very High"

def get_heartrate_status(hr: int) -> str:
    """Helper mapping exactly to status calculations in Flutter's heartratehistory.dart."""
    if hr < 110:
        return "Low"
    elif hr <= 140:
        return "Normal"
    elif hr <= 150:
        return "Elevated"
    return "High"

async def async_process_telemetry(payload: TelemetryPayload):
    """Asynchronous worker resolving ML classifications, updating Firestore, and checking alerts."""
    user_id = payload.userId
    
    # 1. Resolve Sleep Stages dynamically based on heart rate and sensor telemetry
    sleep_analytics = ml_service.analyze_sleep_state(payload.heartRate)
    
    # 2. Compile metrics object for the live dashboard document
    latest_metrics = {
        "temperature": payload.temperature,
        "heartRate": payload.heartRate,
        "roomTemperature": payload.roomTemperature,
        "humidity": payload.humidity,
        "sleepStatus": sleep_analytics["sleepStatus"],
        "cryStatus": "Quiet",
    }
    
    # Write latest to database
    firebase_service.update_latest_telemetry(user_id, latest_metrics)
    
    # 3. Log values to aggregate historical statistics
    temp_status = get_temp_status(payload.temperature)
    hr_status = get_heartrate_status(payload.heartRate)
    
    firebase_service.append_temperature_log(user_id, payload.temperature, temp_status)
    firebase_service.append_heartrate_log(user_id, payload.heartRate, hr_status)
    
    # 4. Trigger alert checks
    evaluate_and_alert(user_id, payload.heartRate, payload.temperature)

@app.get("/health", status_code=status.HTTP_200_OK, tags=["Health"])
async def health_check():
    """Confirms running state and database connectivity status."""
    return {
        "status": "healthy",
        "firebase_mode": "LIVE" if firebase_service.is_live else "MOCK_SIMULATOR"
    }

@app.post("/api/v1/telemetry", status_code=status.HTTP_202_ACCEPTED, tags=["IoT Ingestion"])
async def post_telemetry(payload: TelemetryPayload, background_tasks: BackgroundTasks):
    """Main data receiver endpoint triggered by the wearable band microcontroller.
    Accepts telemetry rapidly and delegates Firestore writes and ML pipelines to background workers.
    """
    background_tasks.add_task(async_process_telemetry, payload)
    return {"status": "success", "message": "Telemetry accepted for background processing"}

@app.post("/api/v1/alert-override", status_code=status.HTTP_200_OK, tags=["Manual Testing"])
async def trigger_manual_alert(payload: AlertOverridePayload):
    """Triggers an instantaneous, mock FCM notification to test mobile routing and emergency sirens."""
    success = firebase_service.send_push_alert(
        user_id=payload.userId,
        title="Emergency Override Alert",
        body=f"Manual test triggered: {payload.metric} is {payload.status} ({payload.value})!",
        data_payload={
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
            "route": "/notifications",
            "metric": payload.metric,
            "value": payload.value,
            "status": payload.status
        }
    )
    if not success:
        return {"status": "warning", "message": "Alert processing complete (running in console mock mode)"}
    return {"status": "success", "message": "Notification successfully sent"}

@app.post("/api/v1/cry-test", status_code=status.HTTP_200_OK, tags=["Manual Testing"])
async def simulate_baby_crying(userId: str, background_tasks: BackgroundTasks):
    """Simulates a baby cry sound event: processes through the ML audio classifier, 
    logs the event to Firestore cries history, and issues a push notification.
    """
    # 1. Run classifier prediction
    cry_analysis = ml_service.classify_cry_audio()
    
    # 2. Append event to Firestore
    background_tasks.add_task(
        firebase_service.append_cry_event,
        userId,
        cry_analysis["reason"],
        cry_analysis["durationSeconds"],
        cry_analysis["intensity"]
    )
    
    # 3. Update dashboard cry status state
    background_tasks.add_task(
        firebase_service.update_latest_telemetry,
        userId,
        {"cryStatus": f"Crying ({cry_analysis['reason']})"}
    )
    
    # 4. Push FCM Warning Alert to Parent
    background_tasks.add_task(
        firebase_service.send_push_alert,
        userId,
        "Cry Detected",
        f"Baby is crying! Cause: {cry_analysis['reason']} (Intensity: {cry_analysis['intensity']}%)",
        {
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
            "route": "/dashboard",
            "metric": "Cry Analysis",
            "value": cry_analysis["reason"],
            "status": "Crying"
        }
    )
    
    return {
        "status": "success",
        "message": "Crying simulated",
        "predicted_reason": cry_analysis["reason"],
        "intensity": cry_analysis["intensity"]
    }

@app.post("/api/v1/settings", status_code=status.HTTP_200_OK, tags=["App Settings Sync"])
async def sync_preferences(payload: UserPreferencesPayload, background_tasks: BackgroundTasks):
    """Stores parent configuration and device alert thresholds into users/{userId}."""
    settings_dict = payload.model_dump()
    user_id = settings_dict.pop("userId")
    
    background_tasks.add_task(firebase_service.update_user_preferences, user_id, settings_dict)
    return {"status": "success", "message": "Preferences synchronization started"}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
