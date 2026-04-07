"""
Vail intent router

Selects a model tier based on heuristic signals from the incoming messages.
Only runs when the client sends a non-explicit model (e.g. "auto" or "vail").
Explicit tier names (aegis-lite, aegis, aegis-pro) bypass routing entirely.

Tiers:
    aegis-lite  — Gemma 4 E2B    fast, simple queries
    aegis       — Gemma 4 26B    default, code, technical
    aegis-pro   — Gemma 4 31B    long context, deep reasoning
"""

import re

EXPLICIT_TIERS = {"aegis-lite", "aegis", "aegis-pro"}

# Rough tokens ≈ words × 1.3
_WORDS_TO_TOKENS = 1.3
_LITE_TOKEN_CEILING  = 60    # below this, candidate for lite
_PRO_TOKEN_FLOOR     = 250   # above this, candidate for pro

_CODE_SIGNALS = re.compile(
    r"```|"
    r"\bdef\b|\bclass\b|\bfunction\b|\bimport\b|\brequire\b|"
    r"\bconst\b|\bvar\b|\blet\b|\bfn\b|\bstruct\b|\benum\b|"
    r"\bbug\b|\berror\b|\bexception\b|\bdebug\b|\bstacktrace\b|"
    r"\bsql\b|\bquery\b|\bregex\b|\bdocker\b|\bkubernetes\b",
    re.IGNORECASE,
)

_PRO_SIGNALS = re.compile(
    r"\banalyze\b|\banalyse\b|\bcompare\b|\bevaluate\b|\bcritique\b|"
    r"\breason\b|\binfer\b|\bprove\b|\bphilosoph|\bstrategy\b|"
    r"\bcomprehensive\b|\bin[- ]depth\b|\bstep[- ]by[- ]step\b|"
    r"\bwrite a (?:detailed|full|complete|long)\b|"
    r"\bplan\b|\barchitect\b|\bdesign\b|\bproposal\b|\brefactor\b",
    re.IGNORECASE,
)

_LITE_SIGNALS = re.compile(
    r"^(hi|hello|hey|thanks|thank you|ok|okay|yes|no|sure|got it|"
    r"what is|what'?s|who is|who'?s|when is|when'?s|how do i|can you)[^.!?]{0,80}[.!?]?$",
    re.IGNORECASE,
)


def _estimate_tokens(text: str) -> int:
    return int(len(text.split()) * _WORDS_TO_TOKENS)


def select_tier(messages: list[dict], requested_model: str) -> str:
    """Return the tier to use for this request.

    If the client explicitly requested a known tier, return it unchanged.
    Otherwise apply heuristics to the last user message.
    """
    if requested_model in EXPLICIT_TIERS:
        return requested_model

    # Extract the last user message as the primary signal
    last_user = ""
    for msg in reversed(messages):
        if msg.get("role") == "user":
            content = msg.get("content", "")
            last_user = content if isinstance(content, str) else str(content)
            break

    if not last_user:
        return "aegis"

    tokens = _estimate_tokens(last_user)

    # Pro: long context or explicit reasoning request
    if tokens >= _PRO_TOKEN_FLOOR or _PRO_SIGNALS.search(last_user):
        return "aegis-pro"

    # Lite: short + no code + matches conversational pattern
    if tokens < _LITE_TOKEN_CEILING and not _CODE_SIGNALS.search(last_user):
        if _LITE_SIGNALS.match(last_user.strip()) or tokens < 20:
            return "aegis-lite"

    # Code / technical signals push to standard tier regardless of length
    if _CODE_SIGNALS.search(last_user):
        return "aegis"

    # Default
    return "aegis"
