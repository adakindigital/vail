"""
Vail Gateway — session management routes

Mounts on the main FastAPI app. All routes require the same API key auth
as the chat completions endpoint.

Routes:
    GET    /v1/sessions              — list all sessions (newest first)
    GET    /v1/sessions/{session_id} — session metadata + full message history
    DELETE /v1/sessions/{session_id} — delete session and all its messages
"""

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import JSONResponse

from api import db as database

router = APIRouter()


def _check_auth(authorization: str, vail_api_key: str) -> None:
    if not vail_api_key:
        return
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    token = authorization.removeprefix("Bearer ").strip()
    if token != vail_api_key:
        raise HTTPException(status_code=401, detail="Invalid API key")


# The API key is injected at route registration time via a closure.
# main.py calls build_router(vail_api_key) to get a configured router.

def build_router(vail_api_key: str) -> APIRouter:
    r = APIRouter()

    @r.get("/v1/sessions")
    async def list_sessions(authorization: str = Header(default="")):
        _check_auth(authorization, vail_api_key)
        sessions = await database.list_sessions()
        return JSONResponse({"sessions": sessions, "count": len(sessions)})

    @r.get("/v1/sessions/{session_id}")
    async def get_session(session_id: str, authorization: str = Header(default="")):
        _check_auth(authorization, vail_api_key)
        session = await database.get_session(session_id)
        if session is None:
            raise HTTPException(status_code=404, detail="Session not found")
        return JSONResponse(session)

    @r.patch("/v1/sessions/{session_id}")
    async def update_session(
        session_id: str,
        body: dict,
        authorization: str = Header(default=""),
    ):
        _check_auth(authorization, vail_api_key)
        title = body.get("title")
        if not title or not isinstance(title, str):
            raise HTTPException(status_code=400, detail="body must include 'title' string")
        await database.set_session_title(session_id, title.strip())
        return JSONResponse({"updated": True, "session_id": session_id})

    @r.delete("/v1/sessions/{session_id}")
    async def delete_session(session_id: str, authorization: str = Header(default="")):
        _check_auth(authorization, vail_api_key)
        deleted = await database.delete_session(session_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Session not found")
        return JSONResponse({"deleted": True, "session_id": session_id})

    return r
