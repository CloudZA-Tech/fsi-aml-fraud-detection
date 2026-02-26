from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
import os

class APIKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path in ["/", "/docs", "/openapi.json", "/health", "/test"]:
            return await call_next(request)
        
        api_key = request.headers.get("X-API-Key")
        expected_key = os.getenv("API_KEY")
        
        if not expected_key or api_key != expected_key:
            raise HTTPException(status_code=401, detail="Invalid or missing API key")
        
        return await call_next(request)
