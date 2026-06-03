from pydantic import BaseModel, Field

class TelemetryPayload(BaseModel):
    """Pydantic model validating incoming hardware sensor data."""
    userId: str = Field(..., description="Firebase Authentication user UID paired to the band")
    temperature: float = Field(..., ge=30.0, le=45.0, description="Baby body temperature in Celsius")
    heartRate: int = Field(..., ge=30, le=250, description="Baby heart rate in beats per minute (BPM)")
    roomTemperature: float = Field(..., description="Ambient room temperature in Celsius")
    humidity: float = Field(..., ge=0.0, le=100.0, description="Ambient room humidity percentage")

class AlertOverridePayload(BaseModel):
    """Pydantic model for forced mock alert overrides."""
    userId: str = Field(..., description="Firebase User UID to target with the push notification")
    metric: str = Field(..., description="The name of the metric crossing thresholds (e.g., Heart rate)")
    value: str = Field(..., description="The value of the alert (e.g., 150 bpm)")
    status: str = Field(..., description="High-level description of state (e.g., Too High)")

class UserPreferencesPayload(BaseModel):
    """Pydantic model to synchronize application preferences from settings."""
    userId: str = Field(...)
    pushNotifications: bool = True
    alertVolume: float = Field(0.8, ge=0.0, le=1.0)
    vibrationAlerts: bool = True
    autoSync: bool = True
    shareBabyData: bool = False
    temperatureUnit: str = "°C"
    distanceUnit: str = "km"
    language: str = "English"
