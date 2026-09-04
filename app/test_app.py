# test_app.py
# Basic unit test. Jenkins runs this in the "Test" stage BEFORE building
# a Docker image, so broken code never reaches production.
from app import app

def test_health():
    client = app.test_client()
    response = client.get("/health")
    assert response.status_code == 200

def test_home():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200
