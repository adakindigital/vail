"""
Vail Gateway — database layer

Single SQLite file in dev (VAIL_DB_URL=./vail_dev.db).
Swap VAIL_DB_URL for a Postgres DSN in prod (Supabase, RDS).

Schema (all CREATE IF NOT EXISTS — safe to run on existing DBs):
  interaction_logs   — every request/response with latency + token counts
  sessions           — named conversation threads
  session_messages   — ordered message history per session
"""

import json
import logging
import aiosqlite
from datetime import datetime, timezone

log = logging.getLogger("vail.db")

_db: aiosqlite.Connection | None = None


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

_CREATE_INTERACTION_LOGS = """
CREATE TABLE IF NOT EXISTS interaction_logs (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at    TEXT    NOT NULL,
    session_id    TEXT,
    model         TEXT    NOT NULL,
    messages_json TEXT    NOT NULL,
    response_text TEXT,
    tokens_in     INTEGER,
    tokens_out    INTEGER,
    latency_ms    REAL,
    stream        INTEGER NOT NULL DEFAULT 0,
    error         TEXT,
    consent       INTEGER NOT NULL DEFAULT 0
);
"""

_CREATE_SESSIONS = """
CREATE TABLE IF NOT EXISTS sessions (
    id            TEXT    PRIMARY KEY,
    created_at    TEXT    NOT NULL,
    updated_at    TEXT    NOT NULL,
    title         TEXT,
    message_count INTEGER NOT NULL DEFAULT 0
);
"""

_CREATE_SESSION_MESSAGES = """
CREATE TABLE IF NOT EXISTS session_messages (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id  TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    sequence    INTEGER NOT NULL,
    role        TEXT    NOT NULL,
    content     TEXT    NOT NULL,
    created_at  TEXT    NOT NULL
);
"""

# Migrations — columns added after initial schema. Safe to run repeatedly.
_MIGRATIONS = [
    "ALTER TABLE interaction_logs ADD COLUMN session_id TEXT",
    "ALTER TABLE interaction_logs ADD COLUMN tokens_in INTEGER",
    "ALTER TABLE interaction_logs ADD COLUMN tokens_out INTEGER",
]


async def open_db(db_url: str) -> aiosqlite.Connection:
    db = await aiosqlite.connect(db_url)
    db.row_factory = aiosqlite.Row

    await db.execute("PRAGMA foreign_keys = ON")
    await db.execute(_CREATE_INTERACTION_LOGS)
    await db.execute(_CREATE_SESSIONS)
    await db.execute(_CREATE_SESSION_MESSAGES)
    await db.commit()

    # Run migrations — ignore "duplicate column" errors (idempotent)
    for migration in _MIGRATIONS:
        try:
            await db.execute(migration)
            await db.commit()
        except Exception:
            pass

    log.info("db open  path=%s", db_url)
    return db


async def close_db(db: aiosqlite.Connection) -> None:
    await db.close()


# ---------------------------------------------------------------------------
# Interaction logs
# ---------------------------------------------------------------------------

async def log_interaction(
    *,
    session_id: str | None,
    model: str,
    messages: list,
    response_text: str | None,
    tokens_in: int | None,
    tokens_out: int | None,
    latency_ms: float,
    stream: bool,
    error: str | None = None,
) -> None:
    """Write one row to interaction_logs. Never raises — fire and forget."""
    db = _db
    if db is None:
        return
    try:
        await db.execute(
            """
            INSERT INTO interaction_logs
                (created_at, session_id, model, messages_json, response_text,
                 tokens_in, tokens_out, latency_ms, stream, error)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                datetime.now(timezone.utc).isoformat(),
                session_id,
                model,
                json.dumps(messages),
                response_text,
                tokens_in,
                tokens_out,
                latency_ms,
                int(stream),
                error,
            ),
        )
        await db.commit()
    except Exception as exc:
        log.error("db write failed: %s", exc)


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------

async def get_or_create_session(session_id: str) -> None:
    """Ensure a session row exists. Creates it if not found."""
    db = _db
    if db is None:
        return
    now = datetime.now(timezone.utc).isoformat()
    await db.execute(
        """
        INSERT OR IGNORE INTO sessions (id, created_at, updated_at, title, message_count)
        VALUES (?, ?, ?, NULL, 0)
        """,
        (session_id, now, now),
    )
    await db.commit()


async def get_session_messages(session_id: str) -> list[dict]:
    """Return all messages for a session, ordered by sequence."""
    db = _db
    if db is None:
        return []
    async with db.execute(
        "SELECT role, content FROM session_messages WHERE session_id = ? ORDER BY sequence ASC",
        (session_id,),
    ) as cursor:
        rows = await cursor.fetchall()
    return [{"role": row["role"], "content": row["content"]} for row in rows]


async def append_session_turn(
    session_id: str,
    user_content: str,
    assistant_content: str,
) -> None:
    """Append a user+assistant turn and update session metadata."""
    db = _db
    if db is None:
        return

    # Get current max sequence
    async with db.execute(
        "SELECT COALESCE(MAX(sequence), 0) AS max_seq FROM session_messages WHERE session_id = ?",
        (session_id,),
    ) as cursor:
        row = await cursor.fetchone()
        next_seq = (row["max_seq"] if row else 0) + 1

    now = datetime.now(timezone.utc).isoformat()

    await db.execute(
        "INSERT INTO session_messages (session_id, sequence, role, content, created_at) VALUES (?, ?, ?, ?, ?)",
        (session_id, next_seq, "user", user_content, now),
    )
    await db.execute(
        "INSERT INTO session_messages (session_id, sequence, role, content, created_at) VALUES (?, ?, ?, ?, ?)",
        (session_id, next_seq + 1, "assistant", assistant_content, now),
    )

    # Set title from first user message, update count and timestamp
    await db.execute(
        """
        UPDATE sessions SET
            updated_at    = ?,
            message_count = message_count + 2,
            title         = CASE WHEN title IS NULL THEN ? ELSE title END
        WHERE id = ?
        """,
        (now, user_content[:80], session_id),
    )
    await db.commit()


async def list_sessions() -> list[dict]:
    db = _db
    if db is None:
        return []
    async with db.execute(
        "SELECT id, created_at, updated_at, title, message_count FROM sessions ORDER BY updated_at DESC"
    ) as cursor:
        rows = await cursor.fetchall()
    return [dict(row) for row in rows]


async def get_session(session_id: str) -> dict | None:
    db = _db
    if db is None:
        return None
    async with db.execute(
        "SELECT id, created_at, updated_at, title, message_count FROM sessions WHERE id = ?",
        (session_id,),
    ) as cursor:
        row = await cursor.fetchone()
    if row is None:
        return None
    messages = await get_session_messages(session_id)
    return {**dict(row), "messages": messages}


async def delete_session(session_id: str) -> bool:
    db = _db
    if db is None:
        return False
    async with db.execute("DELETE FROM sessions WHERE id = ?", (session_id,)) as cursor:
        deleted = cursor.rowcount > 0
    await db.commit()
    return deleted


# ---------------------------------------------------------------------------
# Module-level handle — set by main.py lifespan
# ---------------------------------------------------------------------------

def set_db(db: aiosqlite.Connection) -> None:
    global _db
    _db = db
