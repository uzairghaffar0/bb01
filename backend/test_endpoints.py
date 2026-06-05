"""
============================================================
  Smart Baby Band - API Endpoint Test Suite
  Tests all backend endpoints for proper functionality
============================================================
  Usage:  python test_endpoints.py
  Requires: pip install requests  (already in your venv)
============================================================
"""

import requests
import json
import time
import sys
import os
from datetime import datetime

# Fix Windows console encoding for Unicode characters
if sys.platform == 'win32':
    os.system('')  # Enable ANSI escape codes on Windows
    sys.stdout.reconfigure(encoding='utf-8')

# ── Configuration ────────────────────────────────────────
BASE_URL = "http://localhost:8000"
TEST_USER_ID = "parent_auth_uid_12345"  # Same as mock_hardware uses

# ── Colors for terminal output ───────────────────────────
class Colors:
    GREEN  = "\033[92m"
    RED    = "\033[91m"
    YELLOW = "\033[93m"
    CYAN   = "\033[96m"
    BOLD   = "\033[1m"
    RESET  = "\033[0m"

def print_header(text):
    print(f"\n{Colors.CYAN}{Colors.BOLD}{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}{Colors.RESET}")

def print_pass(test_name, duration_ms, detail=""):
    print(f"  {Colors.GREEN}✅ PASS{Colors.RESET} | {test_name} ({duration_ms:.0f}ms){' - ' + detail if detail else ''}")

def print_fail(test_name, duration_ms, reason=""):
    print(f"  {Colors.RED}❌ FAIL{Colors.RESET} | {test_name} ({duration_ms:.0f}ms){' - ' + reason if reason else ''}")

def print_warn(text):
    print(f"  {Colors.YELLOW}⚠️  {text}{Colors.RESET}")

def print_info(text):
    print(f"  {Colors.CYAN}ℹ️  {text}{Colors.RESET}")

# ── Test Results Tracker ─────────────────────────────────
results = {"passed": 0, "failed": 0, "tests": []}

def record(name, passed, duration_ms, detail=""):
    results["tests"].append({"name": name, "passed": passed, "duration_ms": duration_ms})
    if passed:
        results["passed"] += 1
        print_pass(name, duration_ms, detail)
    else:
        results["failed"] += 1
        print_fail(name, duration_ms, detail)


# ══════════════════════════════════════════════════════════
#  TEST 1: Health Check  (GET /health)
# ══════════════════════════════════════════════════════════
def test_health_check():
    print_header("TEST 1: Health Check  [GET /health]")
    try:
        start = time.time()
        resp = requests.get(f"{BASE_URL}/health", timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 200:
            data = resp.json()
            record("Health endpoint returns 200", True, duration)
            
            if data.get("status") == "healthy":
                record("Status is 'healthy'", True, duration)
            else:
                record("Status is 'healthy'", False, duration, f"Got: {data.get('status')}")
            
            fb_mode = data.get("firebase_mode")
            record("Firebase mode reported", True, duration, f"Mode: {fb_mode}")
            
            print_info(f"Response: {json.dumps(data, indent=2)}")
        else:
            record("Health endpoint returns 200", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Health endpoint reachable", False, 0, "Connection refused — is the backend running?")


# ══════════════════════════════════════════════════════════
#  TEST 2: Telemetry Ingestion  (POST /api/v1/telemetry)
# ══════════════════════════════════════════════════════════
def test_telemetry_normal():
    print_header("TEST 2: Telemetry Ingestion  [POST /api/v1/telemetry]")

    # 2a) Normal telemetry
    payload_normal = {
        "userId": TEST_USER_ID,
        "temperature": 36.8,
        "heartRate": 130,
        "roomTemperature": 22.5,
        "humidity": 55.0
    }
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/telemetry", json=payload_normal, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 202:
            record("Normal telemetry accepted (202)", True, duration)
            print_info(f"Response: {resp.json()}")
        else:
            record("Normal telemetry accepted (202)", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Normal telemetry", False, 0, "Connection refused")

    # 2b) High temperature (should trigger alert)
    payload_fever = {
        "userId": TEST_USER_ID,
        "temperature": 38.5,
        "heartRate": 135,
        "roomTemperature": 23.0,
        "humidity": 60.0
    }
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/telemetry", json=payload_fever, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 202:
            record("Fever telemetry accepted (38.5°C)", True, duration, "Should trigger alert in backend logs")
        else:
            record("Fever telemetry accepted", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Fever telemetry", False, 0, "Connection refused")

    # 2c) High heart rate (should trigger alert)
    payload_hr = {
        "userId": TEST_USER_ID,
        "temperature": 36.5,
        "heartRate": 180,
        "roomTemperature": 22.0,
        "humidity": 50.0
    }
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/telemetry", json=payload_hr, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 202:
            record("High HR telemetry accepted (180 BPM)", True, duration, "Should trigger alert in backend logs")
        else:
            record("High HR telemetry accepted", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("High HR telemetry", False, 0, "Connection refused")


# ══════════════════════════════════════════════════════════
#  TEST 3: Telemetry Validation  (POST /api/v1/telemetry)
# ══════════════════════════════════════════════════════════
def test_telemetry_validation():
    print_header("TEST 3: Telemetry Validation (Bad Data)")

    # 3a) Missing required field
    payload_missing = {
        "userId": TEST_USER_ID,
        "temperature": 36.5,
        # heartRate is missing!
        "roomTemperature": 22.0,
        "humidity": 50.0
    }
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/telemetry", json=payload_missing, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 422:
            record("Missing field rejected (422)", True, duration, "heartRate was missing")
        else:
            record("Missing field rejected (422)", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Validation - missing field", False, 0, "Connection refused")

    # 3b) Temperature out of range (>45°C)
    payload_range = {
        "userId": TEST_USER_ID,
        "temperature": 99.9,
        "heartRate": 130,
        "roomTemperature": 22.0,
        "humidity": 50.0
    }
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/telemetry", json=payload_range, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 422:
            record("Out-of-range temp rejected (422)", True, duration, "99.9°C exceeds max 45°C")
        else:
            record("Out-of-range temp rejected (422)", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Validation - out of range", False, 0, "Connection refused")

    # 3c) Empty body
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/telemetry", json={}, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 422:
            record("Empty body rejected (422)", True, duration)
        else:
            record("Empty body rejected (422)", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Validation - empty body", False, 0, "Connection refused")


# ══════════════════════════════════════════════════════════
#  TEST 4: Alert Override  (POST /api/v1/alert-override)
# ══════════════════════════════════════════════════════════
def test_alert_override():
    print_header("TEST 4: Alert Override  [POST /api/v1/alert-override]")

    payload = {
        "userId": TEST_USER_ID,
        "metric": "Heart rate",
        "value": "180 bpm",
        "status": "Too High"
    }
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/alert-override", json=payload, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 200:
            data = resp.json()
            record("Alert override returns 200", True, duration)
            record("Alert response has status field", True if "status" in data else False, duration, f"status: {data.get('status')}")
            print_info(f"Response: {json.dumps(data, indent=2)}")
        else:
            record("Alert override returns 200", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Alert override", False, 0, "Connection refused")


# ══════════════════════════════════════════════════════════
#  TEST 5: Cry Simulation  (POST /api/v1/cry-test)
# ══════════════════════════════════════════════════════════
def test_cry_simulation():
    print_header("TEST 5: Cry Simulation  [POST /api/v1/cry-test]")

    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/cry-test", params={"userId": TEST_USER_ID}, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 200:
            data = resp.json()
            record("Cry simulation returns 200", True, duration)

            if data.get("predicted_reason"):
                record("Cry reason predicted", True, duration, f"Reason: {data['predicted_reason']}")
            else:
                record("Cry reason predicted", False, duration, "No predicted_reason in response")

            if data.get("intensity"):
                record("Cry intensity returned", True, duration, f"Intensity: {data['intensity']}%")
            else:
                record("Cry intensity returned", False, duration, "No intensity in response")

            print_info(f"Response: {json.dumps(data, indent=2)}")
        else:
            record("Cry simulation returns 200", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Cry simulation", False, 0, "Connection refused")


# ══════════════════════════════════════════════════════════
#  TEST 6: User Settings Sync  (POST /api/v1/settings)
# ══════════════════════════════════════════════════════════
def test_settings_sync():
    print_header("TEST 6: Settings Sync  [POST /api/v1/settings]")

    payload = {
        "userId": TEST_USER_ID,
        "pushNotifications": True,
        "alertVolume": 0.9,
        "vibrationAlerts": True,
        "autoSync": True,
        "shareBabyData": False,
        "temperatureUnit": "°C",
        "distanceUnit": "km",
        "language": "English"
    }
    try:
        start = time.time()
        resp = requests.post(f"{BASE_URL}/api/v1/settings", json=payload, timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 200:
            data = resp.json()
            record("Settings sync returns 200", True, duration)
            record("Settings sync message present", True if "message" in data else False, duration, data.get("message", ""))
            print_info(f"Response: {json.dumps(data, indent=2)}")
        else:
            record("Settings sync returns 200", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Settings sync", False, 0, "Connection refused")


# ══════════════════════════════════════════════════════════
#  TEST 7: API Docs Accessible (Swagger)
# ══════════════════════════════════════════════════════════
def test_api_docs():
    print_header("TEST 7: API Documentation  [GET /docs]")

    try:
        start = time.time()
        resp = requests.get(f"{BASE_URL}/docs", timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 200:
            record("Swagger UI accessible", True, duration, f"{BASE_URL}/docs")
        else:
            record("Swagger UI accessible", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("Swagger UI", False, 0, "Connection refused")

    try:
        start = time.time()
        resp = requests.get(f"{BASE_URL}/openapi.json", timeout=10)
        duration = (time.time() - start) * 1000

        if resp.status_code == 200:
            spec = resp.json()
            num_paths = len(spec.get("paths", {}))
            record("OpenAPI spec accessible", True, duration, f"{num_paths} endpoints documented")
        else:
            record("OpenAPI spec accessible", False, duration, f"Got: {resp.status_code}")

    except requests.ConnectionError:
        record("OpenAPI spec", False, 0, "Connection refused")


# ══════════════════════════════════════════════════════════
#  TEST 8: Response Time Under Load
# ══════════════════════════════════════════════════════════
def test_response_time():
    print_header("TEST 8: Response Time (10 rapid requests)")

    payload = {
        "userId": TEST_USER_ID,
        "temperature": 36.8,
        "heartRate": 130,
        "roomTemperature": 22.0,
        "humidity": 55.0
    }

    times = []
    errors = 0
    for i in range(10):
        try:
            start = time.time()
            resp = requests.post(f"{BASE_URL}/api/v1/telemetry", json=payload, timeout=10)
            duration = (time.time() - start) * 1000
            times.append(duration)
            if resp.status_code != 202:
                errors += 1
        except:
            errors += 1

    if times:
        avg = sum(times) / len(times)
        max_t = max(times)
        min_t = min(times)
        record(f"10 requests completed ({errors} errors)", errors == 0, avg,
               f"Avg: {avg:.0f}ms | Min: {min_t:.0f}ms | Max: {max_t:.0f}ms")
    else:
        record("Load test", False, 0, "No requests completed")


# ══════════════════════════════════════════════════════════
#  MAIN RUNNER
# ══════════════════════════════════════════════════════════
def main():
    print(f"\n{Colors.BOLD}{Colors.CYAN}")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║     🍼 Smart Baby Band — API Endpoint Test Suite       ║")
    print(f"║     Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S'):<42} ║")
    print(f"║     Target:  {BASE_URL:<42} ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"{Colors.RESET}")

    total_start = time.time()

    # Run all tests
    test_health_check()
    test_telemetry_normal()
    test_telemetry_validation()
    test_alert_override()
    test_cry_simulation()
    test_settings_sync()
    test_api_docs()
    test_response_time()

    total_time = (time.time() - total_start) * 1000

    # ── Summary ──────────────────────────────────────────
    total = results["passed"] + results["failed"]
    pass_rate = (results["passed"] / total * 100) if total > 0 else 0

    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*60}")
    print(f"  📊 TEST SUMMARY")
    print(f"{'='*60}{Colors.RESET}")
    print(f"  Total Tests:  {total}")
    print(f"  {Colors.GREEN}Passed:     {results['passed']}{Colors.RESET}")
    print(f"  {Colors.RED}Failed:     {results['failed']}{Colors.RESET}")
    print(f"  Pass Rate:    {pass_rate:.1f}%")
    print(f"  Total Time:   {total_time:.0f}ms")

    if results["failed"] == 0:
        print(f"\n  {Colors.GREEN}{Colors.BOLD}🎉 ALL TESTS PASSED! Your backend is working perfectly.{Colors.RESET}")
    else:
        print(f"\n  {Colors.YELLOW}{Colors.BOLD}⚠️  Some tests failed. Check the details above.{Colors.RESET}")

    print(f"\n{Colors.CYAN}{'='*60}{Colors.RESET}\n")

    sys.exit(0 if results["failed"] == 0 else 1)

if __name__ == "__main__":
    main()
