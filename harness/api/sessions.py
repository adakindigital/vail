"""
Vail Gateway — session management routes

Routes:
    GET    /v1/sessions              — list sessions for the authenticated user
    GET    /v1/sessions/{session_id} — session metadata + full message history
    PATCH  /v1/sessions/{session_id} — rename a session (title field)
    DELETE /v1/sessions/{session_id} — delete session and all its messages
"""

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import JSONResponse

from api import db as database
from api.auth import get_current_user

router = APIRouter()


@router.get("/v1/sessions")
async def list_sessions(user_id: str | None = Depends(get_current_user)):
    sessions = await database.list_sessions(user_id)
    return JSONResponse({"sessions": sessions, "count": len(sessions)})


@router.get("/v1/sessions/{session_id}")
async def get_session(session_id: str, user_id: str | None = Depends(get_current_user)):
    session = await database.get_session(session_id, user_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")
    return JSONResponse(session)


@router.patch("/v1/sessions/{session_id}")
async def update_session(
    session_id: str,
    body: dict,
    user_id: str | None = Depends(get_current_user),
):
    title = body.get("title")
    if not title or not isinstance(title, str):
        raise HTTPException(status_code=400, detail="body must include 'title' string")

    # Verify ownership before updating
    session = await database.get_session(session_id, user_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")

    await database.set_session_title(session_id, title.strip())
    return JSONResponse({"updated": True, "session_id": session_id})


@router.delete("/v1/sessions/{session_id}")
async def delete_session(session_id: str, user_id: str | None = Depends(get_current_user)):
    deleted = await database.delete_session(session_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found")
    return JSONResponse({"deleted": True, "session_id": session_id})


def build_router(_vail_api_key: str = "") -> APIRouter:
    """Kept for backwards compatibility with main.py — returns the module router."""
    return router
