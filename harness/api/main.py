"""
Vail API Gateway

Sits between clients (CLI, Flutter apps) and the model backend.
In dev: clients → gateway (9090) → mlx_lm (8080)
In prod: clients → gateway → LiteLLM (4000) → vLLM / OpenRouter

Run in dev:
    cd harness
    uvicorn api.main:app --port 9090 --reload

Environment variables:
    VAIL_BACKEND_URL      Where the model backend lives (default: http://localhost:8080)
    VAIL_BACKEND_MODEL    Explicit backend model ID (overrides auto-detect)
    VAIL_API_KEY          Required API key — empty disables auth (local dev only)
    VAIL_DB_URL           SQLite file path or Postgres DSN (default: ./vail_dev.db)
    VAIL_RATE_LIMIT_RPM   Requests per minute per key (default: 60, 0 = disabled)
    PORT                  Port to serve on (default: 9090)
"""

import os
import json
import time
import asyncio
import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, Header, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse

from api import db as database
from api import ratelimit
from api.router import select_tier
from api.sessions import build_router

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)s  %(message)s")
log = logging.getLogger("vail.gateway")

BACKEND_URL = os.getenv("VAIL_BACKEND_URL", "http://localhost:8080").rstrip("/")
VAIL_API_KEY = os.getenv("VAIL_API_KEY", "")
DB_URL = os.getenv("VAIL_DB_URL", "./vail_dev.db")
BACKEND_MODEL = os.getenv("VAIL_BACKEND_MODEL", "")

_backend_model_id: str | None = None


# ---------------------------------------------------------------------------
# Backend model auto-detect
# ---------------------------------------------------------------------------

async def _detect_backend_model() -> str | None:
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            resp = await client.get(f"{BACKEND_URL}/v1/models")
            data = resp.json()
            models = data.get("data", [])
            if models:
                return models[0]["id"]
    except Exception:
        pass
    return None


# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _backend_model_id
    db = await database.open_db(DB_URL)
    database.set_db(db)

    if BACKEND_MODEL:
        _backend_model_id = BACKEND_MODEL
        log.info("backend model (from env): %s", _backend_model_id)
    else:
        _backend_model_id = await _detect_backend_model()
        if _backend_model_id:
            log.info("backend model (auto-detected): %s", _backend_model_id)
        else:
            log.warning("backend model unknown — set VAIL_BACKEND_MODEL or start mlx_lm first")

    yield
    await database.close_db(db)


app = FastAPI(title="Vail API Gateway", version="0.2.0", lifespan=lifespan)
app.include_router(build_router(VAIL_API_KEY))


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def check_auth(authorization: str) -> None:
    if not VAIL_API_KEY:
        return
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    token = authorization.removeprefix("Bearer ").strip()
    if token != VAIL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


# ---------------------------------------------------------------------------
# Chat completions
# ---------------------------------------------------------------------------

@app.post("/v1/chat/completions")
async def chat_completions(
    request: Request,
    authorization: str = Header(default=""),
    x_session_id: str = Header(default=""),
):
    check_auth(authorization)

    client_ip = request.client.host if request.client else "unknown"
    ratelimit.check(authorization, client_ip)

    body = await request.json()
    model = body.get("model", "unknown")
    messages: list[dict] = body.get("messages", [])
    is_stream = body.get("stream", False)

    session_id = x_session_id.strip() or None

    # Inject session history before the current messages
    if session_id:
        await database.get_or_create_session(session_id)
        history = await database.get_session_messages(session_id)
        if history:
            # Merge: system messages stay at front, history behind them, new messages last
            system_msgs = [m for m in messages if m.get("role") == "system"]
            non_system = [m for m in messages if m.get("role") != "system"]
            messages = system_msgs + history + non_system
            body = {**body, "messages": messages}

    routed_tier = select_tier(messages, model)
    if routed_tier != model:
        log.info("router   %s → %s", model, routed_tier)

    if _backend_model_id:
        body = {**body, "model": _backend_model_id}
    else:
        body = {**body, "model": routed_tier}

    log.info("request  model=%s  routed=%s  stream=%s  session=%s", model, routed_tier, is_stream, session_id)
    t0 = time.monotonic()

    if is_stream:
        return StreamingResponse(
            _stream_from_backend(body, model, messages, t0, session_id),
            media_type="text/event-stream",
            headers={"X-Accel-Buffering": "no"},
        )

    async with httpx.AsyncClient(timeout=None) as client:
        try:
            resp = await client.post(
                f"{BACKEND_URL}/v1/chat/completions",
                json=body,
                headers={"Content-Type": "application/json"},
            )
        except httpx.ConnectError:
            asyncio.create_task(database.log_interaction(
                session_id=session_id, model=model, messages=messages,
                response_text=None, tokens_in=None, tokens_out=None,
                latency_ms=(time.monotonic() - t0) * 1000, stream=False,
                error="backend unavailable",
            ))
            raise HTTPException(status_code=503, detail="Model backend unavailable")

    elapsed_ms = (time.monotonic() - t0) * 1000
    log.info("response model=%s  latency=%.0fms  status=%d", model, elapsed_ms, resp.status_code)

    data = resp.json()
    response_text = None
    tokens_in = tokens_out = None

    if resp.status_code == 200:
        try:
            response_text = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError):
            pass
        usage = data.get("usage", {})
        tokens_in = usage.get("prompt_tokens")
        tokens_out = usage.get("completion_tokens")

        if session_id and response_text:
            user_content = _last_user_content(messages)
            if user_content:
                asyncio.create_task(database.append_session_turn(session_id, user_content, response_text))

    asyncio.create_task(database.log_interaction(
        session_id=session_id, model=model, messages=messages,
        response_text=response_text, tokens_in=tokens_in, tokens_out=tokens_out,
        latency_ms=elapsed_ms, stream=False,
        error=None if resp.status_code == 200 else str(data),
    ))

    return JSONResponse(content=data, status_code=resp.status_code)


async def _stream_from_backend(
    body: dict,
    model: str,
    messages: list,
    t0: float,
    session_id: str | None,
):
    response_chunks: list[str] = []
    usage_data: dict = {}
    error: str | None = None

    try:
        async with httpx.AsyncClient(timeout=None) as client:
            async with client.stream(
                "POST",
                f"{BACKEND_URL}/v1/chat/completions",
                json=body,
                headers={"Content-Type": "application/json"},
            ) as resp:
                if resp.status_code != 200:
                    error_body = await resp.aread()
                    error = f"backend {resp.status_code}: {error_body[:200]}"
                    log.error("backend error  status=%d  body=%s", resp.status_code, error_body[:200])
                    yield f"data: {json.dumps({'error': {'message': f'backend error {resp.status_code}'}})}\n\n"
                    return

                async for chunk in resp.aiter_bytes():
                    decoded = chunk.decode("utf-8", errors="replace")
                    response_chunks.append(decoded)
                    # Capture usage from the final SSE chunk if present
                    for line in decoded.splitlines():
                        if line.startswith("data: ") and line[6:] != "[DONE]":
                            try:
                                data = json.loads(line[6:])
                                if "usage" in data:
                                    usage_data = data["usage"]
                            except Exception:
                                pass
                    yield chunk

    except httpx.ConnectError:
        error = "backend unreachable"
        log.error("backend unreachable at %s", BACKEND_URL)
        yield f"data: {json.dumps({'error': {'message': 'model backend unavailable'}})}\n\n"

    finally:
        elapsed_ms = (time.monotonic() - t0) * 1000
        log.info("stream done  model=%s  latency=%.0fms", model, elapsed_ms)

        response_text = _extract_content_from_sse("".join(response_chunks))
        tokens_in = usage_data.get("prompt_tokens")
        tokens_out = usage_data.get("completion_tokens")

        if session_id and response_text and not error:
            user_content = _last_user_content(messages)
            if user_content:
                asyncio.create_task(database.append_session_turn(session_id, user_content, response_text))

        asyncio.create_task(database.log_interaction(
            session_id=session_id, model=model, messages=messages,
            response_text=response_text, tokens_in=tokens_in, tokens_out=tokens_out,
            latency_ms=elapsed_ms, stream=True, error=error,
        ))


def _extract_content_from_sse(raw: str) -> str:
    content_parts: list[str] = []
    for line in raw.splitlines():
        if not line.startswith("data: "):
            continue
        payload = line[6:]
        if payload == "[DONE]":
            break
        try:
            chunk = json.loads(payload)
            delta = chunk["choices"][0]["delta"].get("content", "")
            if delta:
                content_parts.append(delta)
        except (json.JSONDecodeError, KeyError, IndexError):
            continue
    return "".join(content_parts)


def _last_user_content(messages: list[dict]) -> str | None:
    for msg in reversed(messages):
        if msg.get("role") == "user":
            content = msg.get("content", "")
            return content if isinstance(content, str) else str(content)
    return None


# ---------------------------------------------------------------------------
# Utility routes
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {"status": "ok", "gateway": "vail", "version": "0.2.0", "backend": BACKEND_URL}


@app.get("/v1/models")
async def list_models():
    async with httpx.AsyncClient(timeout=10) as client:
        try:
            resp = await client.get(f"{BACKEND_URL}/v1/models")
            return JSONResponse(content=resp.json())
        except httpx.ConnectError:
            raise HTTPException(status_code=503, detail="Model backend unavailable")
