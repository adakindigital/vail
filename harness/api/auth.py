"""
Vail Gateway — authentication

Supports two auth modes:
  JWT (web users)    — POST /auth/register or /auth/login → token → Bearer <jwt>
  API key (CLI)      — VAIL_API_KEY env var → Bearer <key>, no user scoping

Environment variables:
    VAIL_JWT_SECRET        Secret key for signing JWTs (required for web auth)
    VAIL_JWT_EXPIRY_DAYS   Token lifetime in days (default: 30)
    VAIL_API_KEY           Legacy CLI key — bypasses JWT auth, user_id = None
"""

import os
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional

import bcrypt as _bcrypt

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import JSONResponse
from jose import JWTError, jwt

from api import db as database

JWT_SECRET = os.getenv("VAIL_JWT_SECRET", "")
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_DAYS = int(os.getenv("VAIL_JWT_EXPIRY_DAYS", "30"))
_VAIL_API_KEY = os.getenv("VAIL_API_KEY", "")


def hash_password(plain: str) -> str:
    return _bcrypt.hashpw(plain.encode(), _bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return _bcrypt.checkpw(plain.encode(), hashed.encode())


def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRY_DAYS)
    return jwt.encode({"sub": user_id, "exp": expire}, JWT_SECRET, algorithm=JWT_ALGORITHM)


async def get_current_user(authorization: str = Header(default="")) -> Optional[str]:
    """
    FastAPI dependency. Returns user_id for JWT auth, None for legacy API key auth.
    Raises 401 if no valid credentials are present.
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    token = authorization.removeprefix("Bearer ").strip()

    # Legacy CLI mode — API key bypasses JWT, sessions not user-scoped
    if _VAIL_API_KEY and token == _VAIL_API_KEY:
        return None

    if not JWT_SECRET:
        raise HTTPException(status_code=401, detail="JWT auth not configured on this server")

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id: str | None = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", status_code=201)
async def register(body: dict):
    email = (body.get("email") or "").strip().lower()
    password = body.get("password") or ""

    if not email or "@" not in email:
        raise HTTPException(status_code=400, detail="Valid email required")
    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")
    if not JWT_SECRET:
        raise HTTPException(status_code=503, detail="Auth not configured on this server")

    user_id = str(uuid.uuid4())
    created = await database.create_user(user_id, email, hash_password(password))
    if not created:
        raise HTTPException(status_code=409, detail="Email already registered")

    return JSONResponse(
        {"token": create_access_token(user_id), "user_id": user_id},
        status_code=201,
    )


@router.post("/login")
async def login(body: dict):
    email = (body.get("email") or "").strip().lower()
    password = body.get("password") or ""

    if not JWT_SECRET:
        raise HTTPException(status_code=503, detail="Auth not configured on this server")

    user = await database.get_user_by_email(email)
    if not user or not verify_password(password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return JSONResponse({
        "token": create_access_token(user["id"]),
        "user_id": user["id"],
    })
