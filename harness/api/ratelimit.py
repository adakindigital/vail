"""
Vail Gateway — in-memory sliding window rate limiter

No extra dependencies. Per API key (or per IP when no key is used).

Environment variables:
    VAIL_RATE_LIMIT_RPM   Requests per minute per key (default: 60, 0 = disabled)
    VAIL_RATE_LIMIT_BURST Max burst above RPM average in a single second (default: 5)
"""

import os
import time
import logging
from collections import deque

from fastapi import HTTPException

log = logging.getLogger("vail.ratelimit")

_RPM = int(os.getenv("VAIL_RATE_LIMIT_RPM", "60"))
_WINDOW = 60.0  # seconds

# key → deque of request timestamps within the window
_windows: dict[str, deque] = {}


def _identity(authorization: str, client_ip: str) -> str:
    """Use the API key as the rate limit identity, falling back to client IP."""
    if authorization.startswith("Bearer "):
        token = authorization.removeprefix("Bearer ").strip()
        if token:
            return f"key:{token[:16]}"  # partial — don't log full key
    return f"ip:{client_ip}"


def check(authorization: str, client_ip: str) -> None:
    """Raise HTTP 429 if the caller has exceeded the rate limit.

    Call this before processing any request. When rate limiting is disabled
    (VAIL_RATE_LIMIT_RPM=0) this is a no-op.
    """
    if _RPM == 0:
        return

    identity = _identity(authorization, client_ip)
    now = time.monotonic()
    cutoff = now - _WINDOW

    window = _windows.get(identity)
    if window is None:
        window = deque()
        _windows[identity] = window

    # Evict timestamps outside the sliding window
    while window and window[0] < cutoff:
        window.popleft()

    if len(window) >= _RPM:
        oldest = window[0]
        retry_after = int(_WINDOW - (now - oldest)) + 1
        log.warning("rate limit hit  identity=%s  count=%d  retry_after=%ds", identity, len(window), retry_after)
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded",
            headers={"Retry-After": str(retry_after)},
        )

    window.append(now)
