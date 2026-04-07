# Vail — V.A.I.L.

Versatile Artificial Intelligence Layer. A model-agnostic harness built on Gemma 4 (Apache 2.0). Vail wraps open-source LLMs, exposes an OpenAI-compatible API, routes between model sizes to control cost, and delivers through Flutter frontends and a Go CLI. Powers Adakin Digital projects internally and is sold as a product externally.

Inspired by Psalm 91 — the scripture of covering and protection. Vail = the covering, the shield.

## Phase 1 — Current State

CLI and gateway foundation is built and running.

Built:
- Go CLI (`vail chat`, `vail ask`) — tools always active, rich UI with themes, slash commands, project memory (`.vail/memory.md`), context tracking
- FastAPI gateway — proxies to mlx_lm, auth, async interaction logging to SQLite (`vail_dev.db`)
- LiteLLM proxy — installed, configured, ready for prod routing
- GoReleaser config — ready, pending GitHub repo

Next:
- Create GitHub repo `adakindigital/vail`
- Heuristic intent router in gateway
- RunPod vLLM trial

## Stack

| Layer | Technology |
|-------|-----------|
| Foundation model | Gemma 4 (Apache 2.0) |
| Local inference (dev) | mlx_lm — Apple Silicon |
| Production inference | vLLM (PagedAttention, continuous batching) |
| API gateway | FastAPI — auth, logging, streaming proxy |
| Multi-provider routing | LiteLLM proxy — 100+ providers, OpenAI-compatible |
| External model fallback | OpenRouter (DeepSeek R1, Kimi K2) |
| Fine-tuning | LoRA via LLaMA Factory or Unsloth → DPO |
| Frontend | Flutter (web, mobile, desktop) |
| CLI | Go — `vail chat`, `vail ask` |

## Model Tiers

| Tier | Model | Use |
|------|-------|-----|
| `aegis-lite` | Gemma 4 E2B 4-bit | Fast, daily dev use |
| `aegis` | Gemma 4 26B MoE 4-bit | Production workhorse |
| `aegis-pro` | Gemma 4 31B 4-bit | Complex reasoning, premium |

Tier names are internal routing identifiers. The product is Vail.

## Dev Chain

```text
CLI (vail) → gateway :9090 → mlx_lm :8080
```

Active repo: `~/Projects/vail`. Models at `~/models/friday/` — shared with Friday, do not copy or move. See `server-runbook.md` to run the stack.

## Links

| | |
|-|-|
| Domain | `vail.adakindigital.com` — target `getvail.ai` when funded |
| GitHub | `adakindigital/vail` |
