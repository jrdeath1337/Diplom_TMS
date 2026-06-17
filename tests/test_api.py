from fastapi.testclient import TestClient
import sys
sys.path.append('Docker/api')
from api_server import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()

def test_generate_validation():
    # Пустой запрос должен получить 422 (не 400)
    response = client.post("/generate", json={})
    assert response.status_code == 422

def test_ui():
    response = client.get("/ui")
    assert response.status_code == 200
    assert "Generate Image" in response.text
