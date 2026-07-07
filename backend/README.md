# Now Playing Backend

Serverless FastAPI backend for the Now Playing iOS app. This service proxies Spotify Web API calls, offloading network requests and securing access patterns.

## Features

- **FastAPI Framework**: High performance, easy to build and maintain, auto-generated OpenAPI documentation.
- **Spotify Web API Proxy**:
  - `GET /api/v1/spotify/me` proxies to Spotify's `/v1/me` profile endpoint.
  - `GET /api/v1/spotify/track/{track_id}` proxies to Spotify's track details endpoint.
  - `GET /api/v1/spotify/audio-features/{track_id}` proxies to Spotify's track audio features endpoint.
- **Serverless Ready**: Configured with Mangum for seamless deployment to AWS Lambda behind API Gateway.
- **Docker Support**: Containerized configuration for easy local development and deployment.

## Getting Started

### Prerequisites

- Python 3.11+
- Virtual environment (recommended)
- Docker (optional)

### Local Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create and activate a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the FastAPI development server:
   ```bash
   uvicorn app.main:app --reload
   ```
   The API will be available at `http://localhost:8000`. You can view the Interactive Swagger documentation at `http://localhost:8000/docs`.

### Running Tests

Run unit and integration tests using `pytest`:
```bash
pytest
```

### Docker

To run the backend inside a Docker container:

```bash
docker build -t nowplaying-backend .
docker run -p 8000:8000 nowplaying-backend
```
