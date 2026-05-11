"""
Vail Gateway — database layer

Postgres via asyncpg in all environments.
Set VAIL_DB_URL to a Postgres DSN:
    postgresql://user:password@host:5432/vail

For local dev:
    docker run --rm -e POSTGRES_PASSWORD=vail -e POSTGRES_DB=vail -p 5432:5432 postgres:16

Schema:
    users              — registered accounts
    interaction_logs   — every request/response with latency + token counts
    sessions           — named conversation threads (owned by a user)
    session_messages   — ordered message history per session (supports tool calling)
"""

import json
import logging
from typing import Optional

import asyncpg

log = logging.getLogger("vail.db")

_pool: asyncpg.Pool | None = None


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

_CREATE_USERS = """
CREATE TABLE IF NOT EXISTS users (
    id            TEXT        PRIMARY KEY,
    email         TEXT        NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

_CREATE_SESSIONS = """
CREATE TABLE IF NOT EXISTS sessions (
    id            TEXT        PRIMARY KEY,
    user_id       TEXT        REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    title         TEXT,
    message_count INTEGER     NOT NULL DEFAULT 0
);
"""

_CREATE_SESSION_MESSAGES = """
CREATE TABLE IF NOT EXISTS session_messages (
    id           SERIAL      PRIMARY KEY,
    session_id   TEXT        NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    sequence     INTEGER     NOT NULL,
    role         TEXT        NOT NULL,
    content      TEXT,
    tool_calls   TEXT,
    tool_call_id TEXT,
    name         TEXT,
    model        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

_CREATE_INTERACTION_LOGS = """
CREATE TABLE IF NOT EXISTS interaction_logs (
    id            SERIAL      PRIMARY KEY,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id       TEXT        REFERENCES users(id),
    session_id    TEXT,
    model         TEXT        NOT NULL,
    messages_json TEXT        NOT NULL,
    response_text TEXT,
    tokens_in     INTEGER,
    tokens_out    INTEGER,
    latency_ms    REAL,
    stream        BOOLEAN     NOT NULL DEFAULT FALSE,
    error         TEXT,
    consent       BOOLEAN     NOT NULL DEFAULT FALSE
);
"""

_CREATE_INDEXES = [
    "CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id)",
    "CREATE INDEX IF NOT EXISTS sessions_updated_at_idx ON sessions(updated_at DESC)",
    "CREATE INDEX IF NOT EXISTS session_messages_session_seq_idx ON session_messages(session_id, sequence)",
    "CREATE INDEX IF NOT EXISTS interaction_logs_user_id_idx ON interaction_logs(user_id)",
]


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

async def open_db(db_url: str) -> asyncpg.Pool:
    pool = await asyncpg.create_pool(db_url, min_size=1, max_size=10)
    async with pool.acquire() as conn:
        await conn.execute(_CREATE_USERS)
        await conn.execute(_CREATE_SESSIONS)
        await conn.execute(_CREATE_SESSION_MESSAGES)
        await conn.execute(_CREATE_INTERACTION_LOGS)
        for stmt in _CREATE_INDEXES:
            await conn.execute(stmt)
    safe = db_url.split("@")[-1] if "@" in db_url else db_url
    log.info("db open  host=%s", safe)
    return pool


async def close_db(pool: asyncpg.Pool) -> None:
    await pool.close()


def set_db(pool: asyncpg.Pool) -> None:
    global _pool
    _pool = pool


# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------

async def create_user(user_id: str, email: str, password_hash: str) -> bool:
    """Insert a new user. Returns False if the email is already taken."""
    pool = _pool
    if pool is None:
        return False
    try:
        async with pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3)",
                user_id, email, password_hash,
            )
        return True
    except asyncpg.UniqueViolationError:
        return False
    except Exception as exc:
        log.error("create_user failed: %s", exc)
        return False


async def get_user_by_email(email: str) -> dict | None:
    pool = _pool
    if pool is None:
        return None
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, email, password_hash FROM users WHERE email = $1", email
        )
    return dict(row) if row else None


# ---------------------------------------------------------------------------
# Interaction logs
# ---------------------------------------------------------------------------

async def log_interaction(
    *,
    user_id: Optional[str],
    session_id: Optional[str],
    model: str,
    messages: list,
    response_text: Optional[str],
    tokens_in: Optional[int],
    tokens_out: Optional[int],
    latency_ms: float,
    stream: bool,
    error: Optional[str] = None,
) -> None:
    """Write one row to interaction_logs. Never raises — fire and forget."""
    pool = _pool
    if pool is None:
        return
    try:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO interaction_logs
                    (user_id, session_id, model, messages_json, response_text,
                     tokens_in, tokens_out, latency_ms, stream, error)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                """,
                user_id, session_id, model, json.dumps(messages),
                response_text, tokens_in, tokens_out, latency_ms, stream, error,
            )
    except Exception as exc:
        log.error("log_interaction failed: %s", exc)


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------

async def get_or_create_session(session_id: str, user_id: Optional[str] = None) -> None:
    pool = _pool
    if pool is None:
        return
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO sessions (id, user_id) VALUES ($1, $2)
            ON CONFLICT (id) DO NOTHING
            """,
            session_id, user_id,
        )


async def get_session_messages(session_id: str) -> list[dict]:
    pool = _pool
    if pool is None:
        return []
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT role, content, model, tool_calls, tool_call_id, name
            FROM session_messages WHERE session_id = $1 ORDER BY sequence ASC
            """,
            session_id,
        )
    messages = []
    for r in rows:
        msg: dict = {"role": r["role"], "content": r["content"]}
        if r["model"]:
            msg["model"] = r["model"]
        if r["tool_calls"]:
            msg["tool_calls"] = json.loads(r["tool_calls"])
        if r["tool_call_id"]:
            msg["tool_call_id"] = r["tool_call_id"]
        if r["name"]:
            msg["name"] = r["name"]
        messages.append(msg)
    return messages


async def append_session_messages(session_id: str, messages: list[dict]) -> bool:
    """Append multiple messages (supports tool call roles) in one transaction.

    Returns True if this was the first messages added to the session.
    """
    pool = _pool
    if pool is None:
        return False

    async with pool.acquire() as conn:
        async with conn.transaction():
            row = await conn.fetchrow(
                """
                SELECT s.message_count, COALESCE(MAX(sm.sequence), 0) AS max_seq
                FROM sessions s
                LEFT JOIN session_messages sm ON sm.session_id = s.id
                WHERE s.id = $1
                GROUP BY s.id
                """,
                session_id,
            )
            is_first = (row["message_count"] == 0) if row else False
            next_seq = (row["max_seq"] if row else 0) + 1

            for i, msg in enumerate(messages):
                tool_calls = msg.get("tool_calls")
                await conn.execute(
                    """
                    INSERT INTO session_messages
                        (session_id, sequence, role, content, model, tool_calls, tool_call_id, name)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                    """,
                    session_id,
                    next_seq + i,
                    msg.get("role"),
                    msg.get("content"),
                    msg.get("model"),
                    json.dumps(tool_calls) if tool_calls else None,
                    msg.get("tool_call_id"),
                    msg.get("name"),
                )

            await conn.execute(
                "UPDATE sessions SET updated_at = NOW(), message_count = message_count + $1 WHERE id = $2",
                len(messages), session_id,
            )

            if is_first:
                first_user = next(
                    (m.get("content") for m in messages if m.get("role") == "user"), "New Session"
                )
                await conn.execute(
                    "UPDATE sessions SET title = $1 WHERE id = $2 AND title IS NULL",
                    str(first_user)[:80], session_id,
                )

    return is_first


async def append_session_turn(
    session_id: str,
    user_content: str,
    assistant_content: str,
    model: str,
) -> bool:
    """Convenience wrapper for a simple user+assistant turn."""
    return await append_session_messages(session_id, [
        {"role": "user", "content": user_content},
        {"role": "assistant", "content": assistant_content, "model": model},
    ])


async def set_session_title(session_id: str, title: str) -> None:
    pool = _pool
    if pool is None:
        return
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE sessions SET title = $1 WHERE id = $2",
            title, session_id,
        )


async def list_sessions(user_id: Optional[str] = None) -> list[dict]:
    """Return sessions for a user. If user_id is None (CLI), returns all sessions."""
    pool = _pool
    if pool is None:
        return []
    async with pool.acquire() as conn:
        if user_id:
            rows = await conn.fetch(
                "SELECT id, created_at, updated_at, title, message_count FROM sessions WHERE user_id = $1 ORDER BY updated_at DESC",
                user_id,
            )
        else:
            rows = await conn.fetch(
                "SELECT id, created_at, updated_at, title, message_count FROM sessions ORDER BY updated_at DESC"
            )
    return [
        {
            "id": r["id"],
            "created_at": r["created_at"].isoformat() if r["created_at"] else None,
            "updated_at": r["updated_at"].isoformat() if r["updated_at"] else None,
            "title": r["title"],
            "message_count": r["message_count"],
        }
        for r in rows
    ]


async def get_session(session_id: str, user_id: Optional[str] = None) -> dict | None:
    """Fetch a session. With user_id, enforces ownership — returns None if not owned."""
    pool = _pool
    if pool is None:
        return None
    async with pool.acquire() as conn:
        if user_id:
            row = await conn.fetchrow(
                "SELECT id, created_at, updated_at, title, message_count FROM sessions WHERE id = $1 AND user_id = $2",
                session_id, user_id,
            )
        else:
            row = await conn.fetchrow(
                "SELECT id, created_at, updated_at, title, message_count FROM sessions WHERE id = $1",
                session_id,
            )
    if row is None:
        return None
    messages = await get_session_messages(session_id)
    return {
        "id": row["id"],
        "created_at": row["created_at"].isoformat() if row["created_at"] else None,
        "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
        "title": row["title"],
        "message_count": row["message_count"],
        "messages": messages,
    }


async def delete_session(session_id: str, user_id: Optional[str] = None) -> bool:
    """Delete a session. With user_id, only deletes if owned by that user."""
    pool = _pool
    if pool is None:
        return False
    async with pool.acquire() as conn:
        if user_id:
            result = await conn.execute(
                "DELETE FROM sessions WHERE id = $1 AND user_id = $2",
                session_id, user_id,
            )
        else:
            result = await conn.execute(
                "DELETE FROM sessions WHERE id = $1", session_id
            )
    return result.split()[-1] != "0"
