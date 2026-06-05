import time
import random
import requests

# Base configuration
SERVER_URL = "http://127.0.0.1:8000/api/v1/telemetry"
# REPLACE this with your actual Firebase User UID (found in Firebase console or printed by your app)
TEST_USER_ID = "Q9YdSQ0oUJWU40YHdeMCPS27Jkk1"

def simulate_baby_band():
    """Simulates real-time sensor loops transmitting from the Smart Baby Band hardware."""
    print("=================================================================")
    print("          SMART BABY BAND - HARDWARE SIMULATOR (IoT)             ")
    print("=================================================================")
    print(f"Target Server Endpoint: {SERVER_URL}")
    print(f"Target Parent User UID : {TEST_USER_ID}\n")
    print("Press Ctrl+C to stop simulation.\n")

    # Start metrics at normal base values
    current_temp = 36.8
    current_hr = 125

    while True:
        try:
            # 1. Randomly wander metrics (mimicking physiological changes)
            current_temp += random.choice([-0.1, 0.0, 0.1])
            current_temp = max(36.0, min(current_temp, 38.5)) # Keep bounds realistic

            current_hr += random.choice([-4, -2, 0, 2, 4])
            current_hr = max(90, min(current_hr, 165)) # Occasionally cross the 150 BPM threshold

            room_temp = round(random.uniform(21.5, 23.5), 1)
            humidity = round(random.uniform(60.0, 68.0), 1)

            # 2. Package into JSON Telemetry Schema
            payload = {
                "userId": TEST_USER_ID,
                "temperature": round(current_temp, 1),
                "heartRate": current_hr,
                "roomTemperature": room_temp,
                "humidity": humidity
            }

            print(f"[{time.strftime('%H:%M:%S')}] Transmitting Telemetry: "
                  f"Body Temp: {payload['temperature']}°C | HR: {payload['heartRate']} BPM | "
                  f"Room Temp: {payload['roomTemperature']}°C | Humidity: {payload['humidity']}%")

            # 3. Transmit packet to FastAPI Backend via HTTP POST
            response = requests.post(SERVER_URL, json=payload, timeout=10)
            
            if response.status_code == 202:
                print("  -> Transmission accepted by backend.")
            else:
                print(f"  -> Transmission warning! Server returned status: {response.status_code}")

            # 4. Randomly trigger a simulated cry event (10% chance)
            if random.random() < 0.10:
                print(f"[{time.strftime('%H:%M:%S')}] 🚨 Simulating a Baby Cry Event...")
                cry_url = SERVER_URL.replace("/telemetry", "/cry-test")
                requests.post(f"{cry_url}?userId={TEST_USER_ID}", timeout=10)

        except requests.exceptions.ConnectionError:
            print("  -> ERROR: Connection failed! Make sure your FastAPI backend is running (uvicorn app.main:app).")
        except Exception as e:
            print(f"  -> ERROR: {e}")

        # Sleep for 5 seconds before next reading
        time.sleep(5)

if __name__ == "__main__":
    simulate_baby_band()
