import pytest
import httpx
from unittest.mock import patch
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Welcome to the Now Playing API", "status": "healthy"}

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

def test_get_me_no_auth():
    response = client.get("/api/v1/spotify/me")
    assert response.status_code == 401
    assert "Missing Authorization header" in response.json()["detail"]

@patch("httpx.AsyncClient.get")
@pytest.mark.asyncio
async def test_get_me_success(mock_get):
    # Setup real httpx.Response mocked to return user profile info
    mock_get.return_value = httpx.Response(
        status_code=200,
        json={
            "display_name": "Test User",
            "images": [{"url": "https://example.com/image.jpg"}]
        }
    )

    # Test via TestClient
    response = client.get("/api/v1/spotify/me", headers={"Authorization": "Bearer fake_token"})
    assert response.status_code == 200
    assert response.json()["display_name"] == "Test User"
    assert response.json()["images"][0]["url"] == "https://example.com/image.jpg"
    mock_get.assert_called_once_with("https://api.spotify.com/v1/me", headers={"Authorization": "Bearer fake_token"})

@patch("httpx.AsyncClient.get")
@pytest.mark.asyncio
async def test_get_track_success(mock_get):
    mock_get.return_value = httpx.Response(
        status_code=200,
        json={
            "id": "12345",
            "name": "Test Song"
        }
    )

    response = client.get("/api/v1/spotify/track/12345", headers={"Authorization": "Bearer fake_token"})
    assert response.status_code == 200
    assert response.json()["name"] == "Test Song"
    mock_get.assert_called_once_with("https://api.spotify.com/v1/tracks/12345", headers={"Authorization": "Bearer fake_token"})

@patch("httpx.AsyncClient.get")
@pytest.mark.asyncio
async def test_get_audio_features_success(mock_get):
    mock_get.return_value = httpx.Response(
        status_code=200,
        json={
            "tempo": 120.0,
            "energy": 0.8
        }
    )

    response = client.get("/api/v1/spotify/audio-features/12345", headers={"Authorization": "Bearer fake_token"})
    assert response.status_code == 200
    assert response.json()["tempo"] == 120.0
    mock_get.assert_called_once_with("https://api.spotify.com/v1/audio-features/12345", headers={"Authorization": "Bearer fake_token"})
