from fastapi.testclient import TestClient
from app.main import app
import time

client = TestClient(app)

def test_root_returns_expected_payload():
    """Test main endpoint returns correct structure"""
    r = client.get("/")
    assert r.status_code == 200
    data = r.json()
    assert data.get("message") == "Automate all the things!"
    assert isinstance(data.get("timestamp"), int)

def test_timestamp_is_recent():
    """Test timestamp is within reasonable range"""
    r = client.get("/")
    data = r.json()
    timestamp = data.get("timestamp")
    current_time = int(time.time())
    assert abs(timestamp - current_time) < 5, \
        f"Timestamp {timestamp} should be within 5 seconds of {current_time}"

def test_health_endpoint():
    """Test health check endpoint exists and returns correct structure"""
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data.get("status") == "healthy"
    assert isinstance(data.get("timestamp"), int)

def test_multiple_requests_different_timestamps():
    """Test that timestamps update on each request"""
    r1 = client.get("/")
    time.sleep(1)
    r2 = client.get("/")

    ts1 = r1.json().get("timestamp")
    ts2 = r2.json().get("timestamp")
    assert ts2 >= ts1, "Second timestamp should be same or later"

def test_message_is_immutable():
    """Test message doesn't change between requests"""
    r1 = client.get("/")
    r2 = client.get("/")

    msg1 = r1.json().get("message")
    msg2 = r2.json().get("message")
    assert msg1 == msg2 == "Automate all the things!"

def test_response_performance():
    """Test response time is acceptable"""
    start = time.time()
    r = client.get("/")
    duration = time.time() - start

    assert r.status_code == 200
    assert duration < 0.5, \
        f"Response took {duration:.3f}s, should be < 500ms"

def test_root_returns_json():
    """Test response content type is JSON"""
    r = client.get("/")
    assert r.headers["content-type"] == "application/json"

def test_health_returns_json():
    """Test health endpoint content type is JSON"""
    r = client.get("/health")
    assert r.headers["content-type"] == "application/json"

def test_concurrent_requests():
    """Test API handles multiple concurrent requests"""
    import concurrent.futures

    def make_request():
        return client.get("/")

    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(make_request) for _ in range(20)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]

    assert all(r.status_code == 200 for r in results), \
        "All concurrent requests should succeed"

def test_invalid_endpoint_returns_404():
    """Test that invalid endpoints return 404"""
    r = client.get("/invalid")
    assert r.status_code == 404
