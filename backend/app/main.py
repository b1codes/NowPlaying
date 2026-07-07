from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum
from app.api.spotify import router as spotify_router

app = FastAPI(
    title="Now Playing Backend",
    description="Serverless FastAPI backend for the Now Playing iOS app.",
    version="1.0.0",
)

# Configure CORS for local development and client access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust this in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(spotify_router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {"message": "Welcome to the Now Playing API", "status": "healthy"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

# Mangum handler for AWS Lambda serverless support
handler = Mangum(app)
