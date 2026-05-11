# TKT-0135 — Nexus Sandbox Makefile
# Compose project: openclaw-sandbox
# Status: DRAFT FOR REVIEW
# Version: 1.0 | 2026-05-10
#
# Usage:
#   make sandbox-build    — Build versioned seed image
#   make sandbox-up       — Start sandbox environment
#   make sandbox-status   — Check running status
#   make sandbox-down     — Stop and destroy sandbox (leaves volume)
#   make sandbox-verify   — Assert zero residual containers/volumes/networks post-teardown
#
# Requirements: Docker (via Colima), docker compose v2

COMPOSE_PROJECT := openclaw-sandbox
COMPOSE_FILE    := docker-compose.sandbox.yml
ENV_FILE        := .env.sandbox
VERIFY_SCRIPT   := ./sandbox-verify.sh

# Colima port-forward address (loopback only — no Tailscale inside container)
SANDBOX_HOST    := 127.0.0.1
SANDBOX_PORT    ?= 3131

.DEFAULT_GOAL := sandbox-status

# ─── Pre-flight check ─────────────────────────────────────────────────────────
.PHONY: _preflight
_preflight:
	@echo "→ Pre-flight: checking .env.sandbox..."
	@test -f $(ENV_FILE) || (echo "ERROR: $(ENV_FILE) not found. Copy .env.sandbox.template and fill in values." && exit 1)
	@echo "→ Pre-flight: checking Docker..."
	@docker info > /dev/null 2>&1 || (echo "ERROR: Docker (Colima) not running." && exit 1)
	@echo "→ Pre-flight: OK"

# ─── sandbox-build ────────────────────────────────────────────────────────────
# Builds the versioned seed image from Dockerfile.sandbox
# Run after any change to seed/ configs or Dockerfile.sandbox
.PHONY: sandbox-build
sandbox-build: _preflight
	@echo "═══════════════════════════════════════════════════"
	@echo "  TKT-0135 Sandbox — Building seed image"
	@echo "═══════════════════════════════════════════════════"
	docker compose \
		-p $(COMPOSE_PROJECT) \
		-f $(COMPOSE_FILE) \
		--env-file $(ENV_FILE) \
		build --no-cache
	@echo "✓ Sandbox image built: openclaw-sandbox:latest"

# ─── sandbox-up ───────────────────────────────────────────────────────────────
# Start the sandbox. Triggered by Yoda after requirements/scope validated.
# Uses cached image layers — target spin-up ~30-60s.
.PHONY: sandbox-up
sandbox-up: _preflight
	@echo "═══════════════════════════════════════════════════"
	@echo "  TKT-0135 Sandbox — Starting"
	@echo "  Compose project: $(COMPOSE_PROJECT)"
	@echo "═══════════════════════════════════════════════════"
	docker compose \
		-p $(COMPOSE_PROJECT) \
		-f $(COMPOSE_FILE) \
		--env-file $(ENV_FILE) \
		up -d
	@echo "→ Waiting for health checks..."
	@sleep 5
	@$(MAKE) sandbox-status
	@echo ""
	@echo "✓ Sandbox UP — OpenClaw accessible at http://$(SANDBOX_HOST):$(SANDBOX_PORT)"
	@echo "  Demo agents: Mini Yoda + Aria"
	@echo "  MinIO console: http://$(SANDBOX_HOST):9131"

# ─── sandbox-down ─────────────────────────────────────────────────────────────
# Full destroy: stops containers, removes containers + named volumes + network.
# 4C Hybrid lifecycle — run after every demo session.
.PHONY: sandbox-down
sandbox-down:
	@echo "═══════════════════════════════════════════════════"
	@echo "  TKT-0135 Sandbox — Destroying (4C Hybrid)"
	@echo "═══════════════════════════════════════════════════"
	docker compose \
		-p $(COMPOSE_PROJECT) \
		-f $(COMPOSE_FILE) \
		down --volumes --remove-orphans
	@echo "→ Running post-teardown verification..."
	@$(MAKE) sandbox-verify
	@echo "✓ Sandbox DESTROYED — no residual state"

# ─── sandbox-verify ───────────────────────────────────────────────────────────
# Assert zero residual containers, volumes, networks post-teardown.
# Atlas hard constraint: this check is MANDATORY (constraint 3).
.PHONY: sandbox-verify
sandbox-verify:
	@echo "═══════════════════════════════════════════════════"
	@echo "  TKT-0135 Sandbox — Post-teardown verification"
	@echo "═══════════════════════════════════════════════════"
	@bash $(VERIFY_SCRIPT) $(COMPOSE_PROJECT)

# ─── sandbox-status ───────────────────────────────────────────────────────────
# Show current sandbox state.
.PHONY: sandbox-status
sandbox-status:
	@echo "═══════════════════════════════════════════════════"
	@echo "  TKT-0135 Sandbox — Status"
	@echo "═══════════════════════════════════════════════════"
	@docker compose \
		-p $(COMPOSE_PROJECT) \
		-f $(COMPOSE_FILE) \
		ps 2>/dev/null || echo "  (no sandbox containers running)"
	@echo ""
	@echo "Volumes:"
	@docker volume ls --filter "name=$(COMPOSE_PROJECT)" 2>/dev/null || true
	@echo ""
	@echo "Networks:"
	@docker network ls --filter "name=$(COMPOSE_PROJECT)" 2>/dev/null || true

# ─── Convenience targets ──────────────────────────────────────────────────────
.PHONY: logs
logs:
	docker compose -p $(COMPOSE_PROJECT) -f $(COMPOSE_FILE) logs -f

.PHONY: shell
shell:
	docker exec -it openclaw-sandbox-app /bin/sh

.PHONY: help
help:
	@echo "TKT-0135 Nexus Sandbox — Available targets:"
	@echo "  sandbox-build   Build versioned seed image"
	@echo "  sandbox-up      Start sandbox environment"
	@echo "  sandbox-down    Stop and destroy sandbox (full teardown)"
	@echo "  sandbox-verify  Assert zero residual state post-teardown"
	@echo "  sandbox-status  Show current container/volume/network state"
	@echo "  logs            Tail sandbox logs"
	@echo "  shell           Shell into openclaw-sandbox-app"
