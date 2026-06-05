import json
import logging
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, firestore, messaging
from app.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("FirebaseService")

class FirebaseService:
    """Handles interactions with Cloud Firestore and Firebase Cloud Messaging (FCM)."""
    
    def __init__(self):
        self.db = None
        self.is_live = False
        self._initialize_firebase()

    def _initialize_firebase(self):
        try:
            # 1. Try to load from json environment string
            if settings.FIREBASE_CREDENTIALS_JSON:
                logger.info("Initializing Firebase Admin SDK using credentials JSON from environment.")
                cred_dict = json.loads(settings.FIREBASE_CREDENTIALS_JSON)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                self.db = firestore.client()
                self.is_live = True
            
            # 2. Try to load from local file path
            elif settings.FIREBASE_CREDENTIALS_PATH:
                cred_path = Path(settings.FIREBASE_CREDENTIALS_PATH)
                if cred_path.exists():
                    logger.info(f"Initializing Firebase Admin SDK using certificate file at {cred_path}.")
                    cred = credentials.Certificate(str(cred_path))
                    firebase_admin.initialize_app(cred)
                    self.db = firestore.client()
                    self.is_live = True
                else:
                    # 3. Try application default credentials
                    try:
                        logger.info("Credentials file not found. Attempting Application Default Credentials (ADC).")
                        firebase_admin.initialize_app()
                        self.db = firestore.client()
                        self.is_live = True
                    except Exception:
                        logger.warning(
                            "------------------------------------------------------------------------------------\n"
                            "WARNING: Firebase credentials could not be loaded.\n"
                            f"Checked credentials path: {settings.FIREBASE_CREDENTIALS_PATH}\n"
                            "The backend will run in MOCK DEMONSTRATION MODE.\n"
                            "Database operations and FCM alerts will be printed to logs instead of hitting Firebase.\n"
                            "To run in live mode, place your Firebase service-account JSON file under the backend root\n"
                            "and set FIREBASE_CREDENTIALS_PATH in your .env file.\n"
                            "------------------------------------------------------------------------------------"
                        )
        except Exception as e:
            logger.error(f"Error during Firebase initialization: {e}. Defaulting to Mock Mode.")

    def update_latest_telemetry(self, user_id: str, payload: dict) -> bool:
        """Merges telemetry parameters into /users/{userId}/health_metrics/latest."""
        payload["lastUpdated"] = firestore.SERVER_TIMESTAMP if self.is_live else "MOCK_SERVER_TIMESTAMP"
        
        if self.is_live and self.db:
            try:
                doc_ref = self.db.collection("users").document(user_id).collection("health_metrics").document("latest")
                doc_ref.set(payload, merge=True)
                logger.info(f"Successfully synced telemetry for {user_id} to Firestore.")
                return True
            except Exception as e:
                logger.error(f"Failed to write telemetry to Firestore: {e}")
                return False
        else:
            logger.info(f"[Mock Mode DB Sync] Document 'users/{user_id}/health_metrics/latest' set to {payload}")
            return True

    def append_temperature_log(self, user_id: str, temperature: float, status: str) -> bool:
        """Appends body temperature log to /users/{userId}/temperature_history/."""
        log_entry = {
            "timestamp": firestore.SERVER_TIMESTAMP if self.is_live else "MOCK_SERVER_TIMESTAMP",
            "value": temperature,
            "status": status
        }
        
        if self.is_live and self.db:
            try:
                self.db.collection("users").document(user_id).collection("temperature_history").add(log_entry)
                return True
            except Exception as e:
                logger.error(f"Failed to log temp history to Firestore: {e}")
                return False
        else:
            logger.info(f"[Mock Mode DB Sync] Appended temperature_history log for {user_id}: {log_entry}")
            return True

    def append_heartrate_log(self, user_id: str, heartRate: int, status: str) -> bool:
        """Appends heart rate log to /users/{userId}/heartrate_history/."""
        log_entry = {
            "timestamp": firestore.SERVER_TIMESTAMP if self.is_live else "MOCK_SERVER_TIMESTAMP",
            "value": heartRate,
            "status": status
        }
        
        if self.is_live and self.db:
            try:
                self.db.collection("users").document(user_id).collection("heartrate_history").add(log_entry)
                return True
            except Exception as e:
                logger.error(f"Failed to log heart rate history to Firestore: {e}")
                return False
        else:
            logger.info(f"[Mock Mode DB Sync] Appended heartrate_history log for {user_id}: {log_entry}")
            return True

    def append_sleep_log(self, user_id: str, sleep_status: str) -> bool:
        """Appends sleep classification log to /users/{userId}/sleep_history/."""
        log_entry = {
            "timestamp": firestore.SERVER_TIMESTAMP if self.is_live else "MOCK_SERVER_TIMESTAMP",
            "status": sleep_status
        }
        
        if self.is_live and self.db:
            try:
                self.db.collection("users").document(user_id).collection("sleep_history").add(log_entry)
                return True
            except Exception as e:
                logger.error(f"Failed to log sleep history to Firestore: {e}")
                return False
        else:
            logger.info(f"[Mock Mode DB Sync] Appended sleep_history log for {user_id}: {log_entry}")
            return True

    def append_cry_event(self, user_id: str, reason: str, duration_seconds: int, intensity: int) -> bool:
        """Logs a classified cry event under /users/{userId}/cries/."""
        log_entry = {
            "timestamp": firestore.SERVER_TIMESTAMP if self.is_live else "MOCK_SERVER_TIMESTAMP",
            "reason": reason,
            "durationSeconds": duration_seconds,
            "intensity": intensity
        }
        
        if self.is_live and self.db:
            try:
                self.db.collection("users").document(user_id).collection("cries").add(log_entry)
                return True
            except Exception as e:
                logger.error(f"Failed to log cry event to Firestore: {e}")
                return False
        else:
            logger.info(f"[Mock Mode DB Sync] Appended cry event for {user_id}: {log_entry}")
            return True

    def update_user_preferences(self, user_id: str, preferences: dict) -> bool:
        """Updates main parent settings inside /users/{userId}."""
        if self.is_live and self.db:
            try:
                self.db.collection("users").document(user_id).set({"settings": preferences}, merge=True)
                logger.info(f"Updated preferences for parent {user_id} in Firestore.")
                return True
            except Exception as e:
                logger.error(f"Failed to update preferences in Firestore: {e}")
                return False
        else:
            logger.info(f"[Mock Mode DB Sync] Merged users/{user_id} settings: {preferences}")
            return True

    def send_push_alert(self, user_id: str, title: str, body: str, data_payload: dict) -> bool:
        """Sends a high-priority push notification through Firebase Cloud Messaging (FCM)."""
        if self.is_live and self.db:
            try:
                # 1. Fetch user's registered FCM device token
                user_doc = self.db.collection("users").document(user_id).get()
                if not user_doc.exists:
                    logger.warning(f"Could not trigger alert: User document {user_id} does not exist.")
                    return False
                
                fcm_token = user_doc.to_dict().get("fcmToken")
                if not fcm_token:
                    logger.warning(f"Could not trigger alert: User {user_id} has no registered fcmToken.")
                    return False
                
                # 2. Package and trigger FCM message
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body
                    ),
                    data=data_payload,
                    token=fcm_token
                )
                
                response = messaging.send(message)
                logger.info(f"FCM alert successfully sent to device token. FCM Response: {response}")
                
                # 3. Log alert to /users/{userId}/notifications subcollection for in-app logs
                alert_log = {
                    "timestamp": firestore.SERVER_TIMESTAMP,
                    "type": "Emergency Alert",
                    "metric": data_payload.get("metric", "Unknown"),
                    "value": data_payload.get("value", "N/A"),
                    "status": data_payload.get("status", "Too High"),
                    "isRead": False
                }
                self.db.collection("users").document(user_id).collection("notifications").add(alert_log)
                return True
                
            except Exception as e:
                logger.error(f"Failed to dispatch FCM push notification: {e}")
                return False
        else:
            logger.info(
                f"[Mock Mode FCM Alert] Dispatching Push Alert to parent {user_id}:\n"
                f"  -> Title: {title}\n"
                f"  -> Body: {body}\n"
                f"  -> Data Payload: {data_payload}"
            )
            return True

firebase_service = FirebaseService()
