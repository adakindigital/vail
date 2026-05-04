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
import re
import json
import time
import asyncio
import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, Header, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from api import db as database
from api import ratelimit
from api.router import select_tier
from api.sessions import build_router
from api import tools

logging.basicConfig(level=logging.DEBUG, format="%(asctime)s  %(levelname)s  %(message)s")
log = logging.getLogger("vail.gateway")

BACKEND_URL = os.getenv("VAIL_BACKEND_URL", "http://localhost:8080").rstrip("/")
VAIL_API_KEY = os.getenv("VAIL_API_KEY", "")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")
DB_URL = os.getenv("VAIL_DB_URL", "./vail_dev.db")
BACKEND_MODEL = os.getenv("VAIL_BACKEND_MODEL", "")
# Max turns of history to inject per request. Each turn = 2 messages (user + assistant).
# Prevents long sessions from overflowing the model's context window.
MAX_HISTORY_TURNS = int(os.getenv("VAIL_MAX_HISTORY_TURNS", "20"))

_backend_model_id: str | None = None

# Tiers that receive the dynamic UI system prompt injection.
_DYNAMIC_UI_TIERS: frozenset[str] = frozenset({"vail-pro", "vail-max"})

# ---------------------------------------------------------------------------
# Dynamic context-gathering (vail_ui) support
# ---------------------------------------------------------------------------

_VAIL_UI_SYSTEM_PROMPT = """You are Vail — an intelligent assistant that can render interactive UI components directly in the conversation to gather context and improve your output quality.

WHEN TO EMIT A UI BLOCK:
- The user's request is vague or ambiguous and more context would significantly improve your answer.
- The task would produce a long-form document — offer the Doc Writer handoff.
- Do NOT emit UI blocks for simple factual questions, short answers, or any task where you already have enough context.

HOW TO EMIT A UI BLOCK:
1. Write your full conversational response as normal text first.
2. After your text response is complete, on a new line, output ONE JSON object inside <vail_ui>...</vail_ui> tags.
CRITICAL: Your response MUST begin with plain conversational text. NEVER start your response with <vail_ui>. NEVER output ONLY a <vail_ui> block. If you output <vail_ui> without preceding text, the block will be lost entirely.

SCHEMA (form with input fields):
<vail_ui>
{
  "ui_type": "form",
  "title": "TELL ME MORE",
  "description": "One sentence explaining what the form is for.",
  "fields": [
    {"key": "unique_key", "label": "Field label", "type": "text", "placeholder": "optional hint"},
    {"key": "tone", "label": "Tone", "type": "dropdown", "options": ["Option A", "Option B", "Option C"]},
    {"key": "details", "label": "Extra details", "type": "textarea"}
  ],
  "actions": [
    {"label": "Generate", "payload": "Please write it now with the context I've provided.", "is_primary": true},
    {"label": "Skip", "payload": "Skip — write a generic version.", "is_primary": false}
  ]
}
</vail_ui>

SCHEMA (doc writer handoff — no input fields):
<vail_ui>
{
  "ui_type": "action",
  "title": "OPEN IN DOC WRITER",
  "description": "Review and edit this document with full formatting controls.",
  "fields": [],
  "actions": [
    {"label": "Open in Doc Writer", "payload": "open_doc_writer", "is_primary": true}
  ]
}
</vail_ui>

RULES:
- One <vail_ui> block per response at most.
- Keep field count to 3 or fewer.
- Action payloads for non-special buttons should be a natural-language instruction the model can act on.
- The special payload "open_doc_writer" opens the document editor and must not be used for anything else.
"""


class _VailUIParser:
    """Streaming interceptor that strips <vail_ui>...</vail_ui> blocks.

    Feed each incoming delta string to process(). It returns the cleaned text
    that should be streamed to the client. The <vail_ui> block is silently
    consumed; parsed components accumulate in self.components.

    Call flush() after the stream ends to release any buffered clean text.
    """

    OPEN = "<vail_ui>"
    # Accept </vail_ui> with optional internal whitespace (model sometimes
    # adds a space or newline before the closing '>').
    CLOSE = "</vail_ui>"
    _CLOSE_RE = re.compile(r"</\s*vail_ui\s*>", re.IGNORECASE)

    def __init__(self) -> None:
        self._buf: str = ""
        self._in_block: bool = False
        self._ui_buf: str = ""
        self.components: list[dict] = []

    def process(self, delta: str) -> str:
        """Return cleaned text to emit. May return empty string."""
        to_emit = ""
        self._buf += delta

        while self._buf:
            if self._in_block:
                close_match = self._CLOSE_RE.search(self._buf)
                if close_match is None:
                    self._ui_buf += self._buf
                    self._buf = ""
                else:
                    self._ui_buf += self._buf[:close_match.start()]
                    self._buf = self._buf[close_match.end():]
                    self._in_block = False
                    self._try_parse_component()
                    self._ui_buf = ""
            else:
                open_idx = self._buf.find(self.OPEN)
                if open_idx == -1:
                    # Only hold back if the buffer ends with a genuine prefix of
                    # OPEN — i.e., the chunk boundary might have split the tag.
                    # In normal responses (no tag in sight) emit everything
                    # immediately so there is zero streaming lag.
                    held = 0
                    for prefix_len in range(min(len(self.OPEN) - 1, len(self._buf)), 0, -1):
                        if self._buf.endswith(self.OPEN[:prefix_len]):
                            held = prefix_len
                            break
                    to_emit += self._buf[:-held] if held else self._buf
                    self._buf = self._buf[-held:] if held else ""
                    break
                else:
                    to_emit += self._buf[:open_idx]
                    self._buf = self._buf[open_idx + len(self.OPEN):]
                    self._in_block = True
                    self._ui_buf = ""

        return to_emit

    def _try_parse_component(self) -> None:
        """Attempt to parse _ui_buf as JSON and add to components.

        Tries several recovery strategies before giving up:
        1. Direct parse of stripped content.
        2. Strip markdown code fences (model sometimes wraps JSON in ```json).
        3. Regex extraction of the first balanced {...} object.
        """
        raw = self._ui_buf.strip()
        if not raw:
            return

        log.debug("dynamic_ui  raw block preview: %r", raw[:200])

        # Strategy 1 — direct parse.
        try:
            self.components.append(json.loads(raw))
            return
        except json.JSONDecodeError:
            pass

        # Strategy 2 — strip markdown code fences.
        stripped = re.sub(r"^```(?:json)?\s*", "", raw, flags=re.MULTILINE)
        stripped = re.sub(r"\s*```\s*$", "", stripped, flags=re.MULTILINE).strip()
        try:
            self.components.append(json.loads(stripped))
            return
        except json.JSONDecodeError:
            pass

        # Strategy 3 — find the first complete {...} object in the content.
        # This handles cases where the model added commentary before/after JSON.
        brace_match = re.search(r"\{.*\}", stripped, re.DOTALL)
        if brace_match:
            try:
                self.components.append(json.loads(brace_match.group()))
                return
            except json.JSONDecodeError:
                pass

        log.warning(
            "dynamic_ui  failed to parse component JSON (len=%d, preview=%r)",
            len(raw), raw[:300],
        )

    def flush(self) -> str:
        """Release any remaining buffer at end of stream.

        If we are still inside a block (model never emitted the close tag),
        attempt to parse whatever JSON was collected so the component is not
        silently lost. The pre-block text in _buf is returned as clean text.
        """
        if self._in_block:
            log.warning("dynamic_ui  stream ended mid-block — attempting salvage parse")
            self._try_parse_component()
            self._in_block = False
            self._ui_buf = ""
        remaining = self._buf
        self._buf = ""
        return remaining


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

# Allow Flutter web (and any local dev origin) to reach the gateway.
# In production, tighten origins to the actual deployed domain.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

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
            # Cap to last N turns so long sessions don't overflow the context window
            max_msgs = MAX_HISTORY_TURNS * 2
            if len(history) > max_msgs:
                history = history[-max_msgs:]
            # Merge: system messages stay at front, history behind them, new messages last
            system_msgs = [m for m in messages if m.get("role") == "system"]
            non_system = [m for m in messages if m.get("role") != "system"]
            messages = system_msgs + history + non_system
            body = {**body, "messages": messages}

    routed_tier = select_tier(messages, model)
    if routed_tier != model:
        log.info("router   %s → %s", model, routed_tier)

    # Inject dynamic UI system prompt for eligible tiers.
    # Prepend before existing system messages so it acts as the base instruction layer.
    if routed_tier in _DYNAMIC_UI_TIERS:
        ui_prompt_msg = {"role": "system", "content": _VAIL_UI_SYSTEM_PROMPT}
        existing_system = [m for m in messages if m.get("role") == "system"]
        non_system_msgs = [m for m in messages if m.get("role") != "system"]
        messages = [ui_prompt_msg] + existing_system + non_system_msgs
        body = {**body, "messages": messages}
        log.info("dynamic_ui  injected system prompt for tier=%s", routed_tier)

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
    # Inject the Vail tier name into the response so the client knows which
    # model produced the response, even if the backend ID is different.
    data["model"] = model
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
                asyncio.create_task(_save_turn_and_title(session_id, user_content, response_text, model))

    asyncio.create_task(database.log_interaction(
        session_id=session_id, model=model, messages=messages,
        response_text=response_text, tokens_in=tokens_in, tokens_out=tokens_out,
        latency_ms=elapsed_ms, stream=False,
        error=None if resp.status_code == 200 else str(data),
    ))

    if resp.status_code == 200:
        choices = data.get("choices", [])
        if choices and choices[0].get("finish_reason") == "tool_calls":
            tool_calls = choices[0]["message"].get("tool_calls", [])
            gateway_tools = [tc for tc in tool_calls if tc["function"]["name"] in ("web_search", "fetch_url")]
            
            if gateway_tools:
                log.info("gateway_tools  executing %d tool(s) server-side", len(gateway_tools))
                messages.append(choices[0]["message"])
                
                for tc in gateway_tools:
                    name = tc["function"]["name"]
                    args_raw = tc["function"]["arguments"]
                    try:
                        args = json.loads(args_raw)
                    except:
                        args = {}
                    
                    if name == "web_search":
                        res = await tools.execute_web_search(args.get("query", ""), TAVILY_API_KEY)
                    elif name == "fetch_url":
                        res = await tools.execute_fetch_url(args.get("url", ""))
                    else:
                        res = f"error: {name} not supported"
                    
                    messages.append({"role": "tool", "tool_call_id": tc.get("id"), "name": name, "content": res})
                
                body["messages"] = messages
                # Recursion handles subsequent model turns
                return await chat_completions(request, authorization, x_session_id)

    # Final save for non-streaming
    if resp.status_code == 200 and session_id:
        response_text = data["choices"][0]["message"]["content"]
        if response_text:
            new_msgs = []
            for i in range(len(messages) - 1, -1, -1):
                new_msgs.insert(0, messages[i])
                if messages[i].get("role") == "user":
                    break
            
            # The last message in messages is the final assistant response
            if new_msgs and new_msgs[-1]["role"] == "assistant":
                new_msgs[-1]["content"] = response_text
                new_msgs[-1]["model"] = model
            
            asyncio.create_task(_save_messages_and_title(session_id, new_msgs))

    return JSONResponse(content=data, status_code=resp.status_code)


async def _stream_from_backend(
    body: dict,
    model: str,
    messages: list,
    t0: float,
    session_id: str | None,
):
    full_response_text: list[str] = []
    usage_data: dict = {}
    error: str | None = None
    
    # Tool execution loop
    while True:
        parser = _VailUIParser()
        tool_calls_accum = {}
        finish_reason = None
        current_response_chunks = []

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
                        yield f"data: {json.dumps({'error': {'message': f'Backend error ({resp.status_code})'}})}\n\n"
                        return

                    buffer = ""
                    done_seen = False

                    async for chunk in resp.aiter_text():
                        buffer += chunk
                        while "\n\n" in buffer:
                            block, buffer = buffer.split("\n\n", 1)
                            current_response_chunks.append(block + "\n\n")

                            output_lines = []
                            for line in block.splitlines():
                                if line.startswith("data: "):
                                    raw_payload = line[6:].strip()
                                    if raw_payload == "[DONE]":
                                        done_seen = True
                                        flush_text = parser.flush()
                                        if flush_text:
                                            output_lines.append(f"data: {json.dumps(_make_delta_chunk(flush_text, model))}")
                                        if parser.components:
                                            output_lines.append(f"data: {json.dumps({'model': model, 'ui_components': parser.components, 'choices': [{'delta': {'content': ''}, 'index': 0}]})}")
                                            parser.components = []
                                        output_lines.append(line)
                                        continue
                                    
                                    try:
                                        data = json.loads(raw_payload)
                                        data["model"] = model
                                        if "usage" in data:
                                            usage_data = data["usage"]
                                        
                                        choice = data["choices"][0]
                                        if "finish_reason" in choice and choice["finish_reason"]:
                                            finish_reason = choice["finish_reason"]

                                        delta = choice.get("delta", {})
                                        
                                        # Handle tool calls in the stream
                                        if "tool_calls" in delta:
                                            for tcd in delta["tool_calls"]:
                                                idx = tcd["index"]
                                                if idx not in tool_calls_accum:
                                                    tool_calls_accum[idx] = {"id": "", "type": "function", "function": {"name": "", "arguments": ""}}
                                                tc = tool_calls_accum[idx]
                                                if "id" in tcd: tc["id"] = tcd["id"]
                                                if "function" in tcd:
                                                    if "name" in tcd["function"]: tc["function"]["name"] += tcd["function"]["name"]
                                                    if "arguments" in tcd["function"]: tc["function"]["arguments"] += tcd["function"]["arguments"]
                                            # Suppress tool calls from reaching the client
                                            continue

                                        # Handle content
                                        content = delta.get("content") or ""
                                        if content:
                                            clean = parser.process(content)
                                            if clean:
                                                data["choices"][0]["delta"]["content"] = clean
                                                output_lines.append(f"data: {json.dumps(data)}")
                                        else:
                                            output_lines.append(f"data: {json.dumps(data)}")
                                    except Exception:
                                        output_lines.append(line)
                                else:
                                    output_lines.append(line)

                            if output_lines:
                                yield ("\n".join(output_lines) + "\n\n").encode("utf-8")

                    if not done_seen and buffer.strip():
                        # Handle trailing data if needed (similar logic to above)
                        pass
            
            # If we accumulated tool calls, we need to decide whether to execute them
            if tool_calls_accum:
                tool_calls = [tc for idx, tc in sorted(tool_calls_accum.items())]
                gateway_tools = [tc for tc in tool_calls if tc["function"]["name"] in ("web_search", "fetch_url")]
                
                if gateway_tools:
                    log.info("gateway_tools  executing %d tool(s) server-side", len(gateway_tools))
                    
                    # Notify client we are working
                    status_msg = "Searching the web..." if any(tc["function"]["name"] == "web_search" for tc in gateway_tools) else "Fetching page content..."
                    yield f"data: {json.dumps(_make_ui_status_chunk(status_msg, model))}\n\n".encode("utf-8")

                    # Add the turn to messages
                    messages.append({"role": "assistant", "content": None, "tool_calls": tool_calls})
                    
                    for tc in gateway_tools:
                        name = tc["function"]["name"]
                        args_raw = tc["function"]["arguments"]
                        try:
                            args = json.loads(args_raw)
                        except:
                            args = {}
                        
                        if name == "web_search":
                            res = await tools.execute_web_search(args.get("query", ""), TAVILY_API_KEY)
                        elif name == "fetch_url":
                            res = await tools.execute_fetch_url(args.get("url", ""))
                        else:
                            res = f"error: {name} not supported"
                        
                        messages.append({"role": "tool", "tool_call_id": tc["id"], "name": name, "content": res})
                    
                    # Loop back to model
                    body["messages"] = messages
                    continue
                else:
                    # Pass non-gateway tools to client (we didn't yield them during streaming)
                    # This is tricky because we already suppressed them. 
                    # For now, let's assume we either handle all or handle none in a single turn.
                    pass

            # If we didn't loop, we are done
            full_response_text.append(_extract_content_from_sse("".join(current_response_chunks)))
            break

        except httpx.ConnectError:
            error = "backend unreachable"
            yield f"data: {json.dumps({'error': {'message': 'model backend unavailable'}})}\n\n"
            break
        except Exception as e:
            error = str(e)
            log.exception("stream loop error")
            break

    # Final cleanup and logging
    elapsed_ms = (time.monotonic() - t0) * 1000
    log.info("stream done  model=%s  latency=%.0fms", model, elapsed_ms)

    final_text = "".join(full_response_text)
    if final_text:
        final_text = re.sub(r"<vail_ui>.*?</vail_ui>", "", final_text, flags=re.DOTALL).strip()
    
    if session_id and final_text and not error:
        user_content = _last_user_content(messages)
        if user_content:
            # Reconstruct the turns to save to the DB.
            # We want to save everything from the FIRST message that isn't already in history.
            # But wait, history was already injected.
            # The 'messages' list now contains: [system, history, user, assistant(tool_calls), tool, ..., assistant(final)]
            # We only want to save the NEW parts: [user, assistant(tool_calls), tool, ..., assistant(final)]
            
            # Find where history ends.
            history_len = 0
            if session_id:
                # This is a bit complex to find exactly, but we know the new messages 
                # were appended to the end of the list before select_tier.
                # Actually, let's just find the last 'user' message and everything after it.
                new_msgs = []
                for i in range(len(messages) - 1, -1, -1):
                    new_msgs.insert(0, messages[i])
                    if messages[i].get("role") == "user":
                        break
                
                # Update the final assistant message's content before saving
                if new_msgs and new_msgs[-1]["role"] == "assistant":
                    new_msgs[-1]["content"] = final_text
                    new_msgs[-1]["model"] = model
                
                asyncio.create_task(_save_messages_and_title(session_id, new_msgs))

    asyncio.create_task(database.log_interaction(
        session_id=session_id, model=model, messages=messages,
        response_text=final_text, tokens_in=usage_data.get("prompt_tokens"), 
        tokens_out=usage_data.get("completion_tokens"),
        latency_ms=elapsed_ms, stream=True, error=error,
    ))


def _make_ui_status_chunk(message: str, model: str) -> dict:
    """Wrap a status message as a ui_component SSE chunk."""
    return {
        "model": model,
        "ui_components": [
            {
                "ui_type": "status",
                "description": message
            }
        ],
        "choices": [{"delta": {"content": ""}, "index": 0}],
    }


def _make_delta_chunk(content: str, model: str) -> dict:
    """Wrap a text string as a minimal OpenAI-compatible delta chunk."""
    return {
        "model": model,
        "choices": [{"delta": {"content": content, "role": "assistant"}, "index": 0}],
    }


async def _generate_session_title(session_id: str, user_content: str) -> None:
    """Generate a short session title from the first user message and persist it.

    Uses a direct backend call — not routed through the gateway — to avoid
    polluting session history with the title prompt. Fire-and-forget: any
    failure is logged and silently swallowed.
    """
    if not _backend_model_id:
        return
    prompt = (
        "Generate a concise 4-6 word title for a conversation that starts with "
        "the following message. Reply with only the title — no punctuation at the "
        f"end, no quotes:\n\n{user_content[:300]}"
    )
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                f"{BACKEND_URL}/v1/chat/completions",
                json={
                    "model": _backend_model_id,
                    "messages": [{"role": "user", "content": prompt}],
                    "stream": False,
                    "max_tokens": 20,
                    "temperature": 0.3,
                },
                headers={"Content-Type": "application/json"},
            )
        if resp.status_code == 200:
            data = resp.json()
            choices = data.get("choices")
            if choices and len(choices) > 0:
                message = choices[0].get("message")
                if message:
                    content = message.get("content", "").strip().strip('"\'').strip()
                    if content:
                        await database.set_session_title(session_id, content)
                        log.info("title generated  session=%s  title=%r", session_id, content)
    except Exception as exc:
        log.warning("title generation failed  session=%s  error=%s", session_id, exc)

async def _save_messages_and_title(
    session_id: str,
    messages: list[dict],
) -> None:
    """Save all messages in a turn and, if first turn, generate a title."""
    is_first = await database.append_session_messages(session_id, messages)
    if is_first:
        user_content = next((m.get("content") for m in messages if m.get("role") == "user"), "")
        asyncio.create_task(_generate_session_title(session_id, user_content))


async def _save_turn_and_title(
...
    session_id: str,
    user_content: str,
    assistant_content: str,
    model: str,
) -> None:
    """Save the turn and, if it is the first one, generate a session title."""
    is_first = await database.append_session_turn(session_id, user_content, assistant_content, model)
    if is_first:
        asyncio.create_task(_generate_session_title(session_id, user_content))


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
