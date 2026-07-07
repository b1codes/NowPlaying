import httpx
from fastapi import APIRouter, Header, HTTPException, status

router = APIRouter(prefix="/spotify", tags=["spotify"])

SPOTIFY_API_URL = "https://api.spotify.com/v1"

@router.get("/me")
async def get_me(authorization: str = Header(None)):
    """
    Fetches the Spotify user profile by proxying the request to Spotify Web API.
    Expects the Spotify access token in the Authorization header.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header"
        )
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                f"{SPOTIFY_API_URL}/me",
                headers={"Authorization": authorization}
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Spotify API returned error {response.status_code}: {response.text}"
                )
            
            return response.json()
            
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to communicate with Spotify: {exc}"
            )

@router.get("/track/{track_id}")
async def get_track(track_id: str, authorization: str = Header(None)):
    """
    Fetches track metadata from Spotify Web API by track ID.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header"
        )
        
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                f"{SPOTIFY_API_URL}/tracks/{track_id}",
                headers={"Authorization": authorization}
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Spotify API returned error {response.status_code}: {response.text}"
                )
                
            return response.json()
            
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to communicate with Spotify: {exc}"
            )

@router.get("/audio-features/{track_id}")
async def get_audio_features(track_id: str, authorization: str = Header(None)):
    """
    Fetches track audio features (BPM, energy, danceability, etc.) from Spotify Web API.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header"
        )
        
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                f"{SPOTIFY_API_URL}/audio-features/{track_id}",
                headers={"Authorization": authorization}
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Spotify API returned error {response.status_code}: {response.text}"
                )
                
            return response.json()
            
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to communicate with Spotify: {exc}"
            )
