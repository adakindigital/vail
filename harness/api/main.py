"""
Vail API Gateway

Sits between clients (CLI, Flutter apps) and the model backend.
In dev: clients → gateway (9090) → mlx_lm (8080)
In prod: clients → gateway → LiteLLM (4000) → vLLM / OpenRouter

Run in dev:
    cd harness
    uvicorn api.main:app --port 9090 --reload

Environment variables:
    VAIL_BACKEND_URL   Where LiteLLM proxy lives (default: http://localhost:4000)
    VAIL_API_KEY       Required API key — leave empty to disable auth (local dev only)
    VAIL_DB_URL        SQLite file path or Postgres DSN (default: ./vail_dev.db)
    PORT                Port to serve on (default: 9090)
"""

import os
import json
import time
import logging
import asyncio
import aiosqlite
from datetime import datetime, timezone
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, Header, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)s  %(message)s")
log = logging.getLogger("vail.gateway")

BACKEND_URL = os.getenv("VAIL_BACKEND_URL", "http://localhost:8080").rstrip("/")
VAIL_API_KEY = os.getenv("VAIL_API_KEY", "")         # empty = no auth (dev mode)
DB_URL = os.getenv("VAIL_DB_URL", "./vail_dev.db")
BACKEND_MODEL = os.getenv("VAIL_BACKEND_MODEL", "")   # explicit backend model ID (overrides auto-detect)

# ---------------------------------------------------------------------------
# Database — interaction_logs
# ---------------------------------------------------------------------------

_db: aiosqlite.Connection | None = None
_backend_model_id: str | None = None  # actual model ID reported by the backend


async def _detect_backend_model() -> str | None:
    """Query the backend's /v1/models to get the loaded model ID.
    mlx_lm (and vLLM) report the exact model string they expect in requests.
    If the backend isn't up yet, returns None and the model field passes through as-is.
    """
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

CREATE_SCHEMA = """
CREATE TABLE IF NOT EXISTS interaction_logs (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at    TEXT    NOT NULL,
    model         TEXT    NOT NULL,
    messages_json TEXT    NOT NULL,   -- full input message array (JSON)
    response_text TEXT,               -- assistant reply (null on error)
    latency_ms    REAL,
    stream        INTEGER NOT NULL DEFAULT 0,
    error         TEXT,               -- error message if the request failed
    consent       INTEGER NOT NULL DEFAULT 0  -- 1 = user opted in for training data
);
"""


async def _open_db() -> aiosqlite.Connection:
    """Open (or create) the local SQLite dev database."""
    db = await aiosqlite.connect(DB_URL)
    await db.execute(CREATE_SCHEMA)
    await db.commit()
    log.info("db open  path=%s", DB_URL)
    return db


async def log_interaction(
    *,
    model: str,
    messages: list,
    response_text: str | None,
    latency_ms: float,
    stream: bool,
    error: str | None = None,
) -> None:
    """Write one row to interaction_logs. Fire-and-forget — never blocks a request."""
    if _db is None:
        return
    try:
        await _db.execute(
            """
            INSERT INTO interaction_logs
                (created_at, model, messages_json, response_text, latency_ms, stream, error)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                datetime.now(timezone.utc).isoformat(),
                model,
                json.dumps(messages),
                response_text,
                latency_ms,
                int(stream),
                error,
            ),
        )
        await _db.commit()
    except Exception as exc:  # noqa: BLE001
        log.error("db write failed: %s", exc)


# ---------------------------------------------------------------------------
# App lifecycle
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _db, _backend_model_id
    _db = await _open_db()
    if BACKEND_MODEL:
        _backend_model_id = BACKEND_MODEL
        log.info("backend model (from env): %s", _backend_model_id)
    else:
        _backend_model_id = await _detect_backend_model()
        if _backend_model_id:
            log.info("backend model (auto-detected): %s", _backend_model_id)
        else:
            log.warning("backend model unknown — set VAIL_BACKEND_MODEL or start mlx_lm before the gateway")
    yield
    if _db:
        await _db.close()


app = FastAPI(title="Vail API Gateway", version="0.1.0", lifespan=lifespan)


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def check_auth(authorization: str) -> None:
    """Raise 401 if an API key is configured and the request doesn't supply it."""
    if not VAIL_API_KEY:
        return
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    token = authorization.removeprefix("Bearer ").strip()
    if token != VAIL_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.post("/v1/chat/completions")
async def chat_completions(request: Request, authorization: str = Header(default="")):
    check_auth(authorization)

    body = await request.json()
    model = body.get("model", "unknown")
    messages = body.get("messages", [])
    is_stream = body.get("stream", False)

    # Rewrite the model field to the backend's actual model ID.
    # mlx_lm (and vLLM) use the model field to select which weights to load —
    # sending a tier name like "aegis-lite" causes mlx_lm to try fetching it from HuggingFace.
    if _backend_model_id:
        body = {**body, "model": _backend_model_id}

    log.info("request  model=%s  stream=%s", model, is_stream)
    t0 = time.monotonic()

    if is_stream:
        return StreamingResponse(
            _stream_from_backend(body, model, messages, t0),
            media_type="text/event-stream",
            headers={"X-Accel-Buffering": "no"},
        )

    # Non-streaming
    async with httpx.AsyncClient(timeout=None) as client:
        try:
            resp = await client.post(
                f"{BACKEND_URL}/v1/chat/completions",
                json=body,
                headers={"Content-Type": "application/json"},
            )
        except httpx.ConnectError:
            asyncio.create_task(log_interaction(
                model=model, messages=messages, response_text=None,
                latency_ms=(time.monotonic() - t0) * 1000, stream=False,
                error="backend unavailable",
            ))
            raise HTTPException(status_code=503, detail="Model backend unavailable")

    elapsed_ms = (time.monotonic() - t0) * 1000
    log.info("response model=%s  latency=%.0fms  status=%d", model, elapsed_ms, resp.status_code)

    data = resp.json()
    response_text = None
    if resp.status_code == 200:
        try:
            response_text = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError):
            pass

    asyncio.create_task(log_interaction(
        model=model, messages=messages, response_text=response_text,
        latency_ms=elapsed_ms, stream=False,
        error=None if resp.status_code == 200 else str(data),
    ))

    return JSONResponse(content=data, status_code=resp.status_code)


async def _stream_from_backend(body: dict, model: str, messages: list, t0: float):
    """Proxy a streaming response from the backend, yielding SSE chunks.
    Buffers the response content so we can log it after the stream finishes.
    """
    response_chunks: list[str] = []
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
                    response_chunks.append(chunk.decode("utf-8", errors="replace"))
                    yield chunk

    except httpx.ConnectError:
        error = "backend unreachable"
        log.error("backend unreachable at %s", BACKEND_URL)
        yield f"data: {json.dumps({'error': {'message': 'model backend unavailable'}})}\n\n"

    finally:
        elapsed_ms = (time.monotonic() - t0) * 1000
        log.info("stream done  model=%s  latency=%.0fms", model, elapsed_ms)

        response_text = _extract_content_from_sse("".join(response_chunks))
        asyncio.create_task(log_interaction(
            model=model, messages=messages, response_text=response_text,
            latency_ms=elapsed_ms, stream=True, error=error,
        ))


def _extract_content_from_sse(raw: str) -> str:
    """Parse buffered SSE text and reconstruct the assistant's content."""
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


@app.get("/health")
async def health():
    return {"status": "ok", "gateway": "vail", "backend": BACKEND_URL}


@app.get("/v1/models")
async def list_models():
    """Proxy the model list from the backend."""
    async with httpx.AsyncClient(timeout=10) as client:
        try:
            resp = await client.get(f"{BACKEND_URL}/v1/models")
            return JSONResponse(content=resp.json())
        except httpx.ConnectError:
            raise HTTPException(status_code=503, detail="Model backend unavailable")
