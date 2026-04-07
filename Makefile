BINARY   := vail
INSTALL  := $(HOME)/.local/bin/$(BINARY)
VENV     := .venv/bin
MODELS   := $(HOME)/models/friday

# Model tier → local path mapping
# Override at the command line: make gateway MODEL=aegis-pro
MODEL ?= aegis-lite

MODEL_aegis-lite := $(MODELS)/gemma-4-e2b-it-4bit
MODEL_aegis      := $(MODELS)/gemma-4-26b-a4b-it-4bit
MODEL_aegis-pro  := $(MODELS)/gemma-4-31b-it-4bit
MODEL_aegis-max  := $(MODELS)/gemma-4-31b-it-4bit

BACKEND_MODEL := $(MODEL_$(MODEL))

.PHONY: build install dev clean gateway litellm

build:
	go build -o $(BINARY) .

install: build
	cp $(BINARY) $(INSTALL)
	@echo "installed → $(INSTALL)"

# Start the FastAPI gateway (port 9090 → mlx_lm on 8080).
# Tells the gateway the exact model ID mlx_lm is serving so it rewrites the
# model field in forwarded requests (prevents mlx_lm hitting HuggingFace).
gateway:
	cd harness && VAIL_BACKEND_MODEL=$(BACKEND_MODEL) ../$(VENV)/uvicorn api.main:app --port 9090 --reload

# Start the LiteLLM proxy (port 4000 → mlx_lm on 8080).
# Not needed in dev — wire in when vLLM / OpenRouter endpoints are ready.
litellm:
	cd harness && ../$(VENV)/litellm --config litellm_config.yaml --port 4000

dev: install
	@echo "ready — run: make gateway  (optionally: make gateway MODEL=aegis-pro)"

clean:
	rm -f $(BINARY)
