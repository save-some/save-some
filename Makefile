# save-some — containerised backend.
#
#   make build      build the API image
#   make start      start the containers (builds first if the image is missing)
#   make start-api  start the API and wait until it answers
#   make quit-api   stop the API, leaving the database up
#   make clean      stop the containers
#
# `make help` lists everything, including the extras below the main five.

COMPOSE ?= docker compose
API_PORT ?= 8000
DB_PORT  ?= 5433
IMAGE    ?= save-some-api:latest

# Every recipe is a command, not a file to produce.
.PHONY: help build start start-api quit-api clean logs shell psql seed reset-db status test-api nuke

.DEFAULT_GOAL := help

help: ## List the available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Build the API container image
	$(COMPOSE) build api

start: ## Start the containers, building the image if it doesn't exist yet
	@# Without this a clean checkout would fail on a missing image rather than
	@# just building it, which makes `make start` a worse first command than it
	@# needs to be.
	@docker image inspect $(IMAGE) >/dev/null 2>&1 || $(MAKE) build
	$(COMPOSE) up -d
	@echo "api      -> http://127.0.0.1:$(API_PORT)/v1/health"
	@echo "api docs -> http://127.0.0.1:$(API_PORT)/docs"
	@echo "postgres -> 127.0.0.1:$(DB_PORT)"

start-api: ## Start the API and block until it actually serves
	@docker image inspect $(IMAGE) >/dev/null 2>&1 || $(MAKE) build
	@# --wait honours the healthcheck in the Dockerfile, so this returns when the
	@# API can serve rather than when the process has merely been created.
	$(COMPOSE) up -d --wait api
	@echo "api ready -> http://127.0.0.1:$(API_PORT)/v1/health"

quit-api: ## Stop the API, leaving the database running
	$(COMPOSE) stop api

clean: ## Stop the containers
	$(COMPOSE) stop

# ---------------------------------------------------------------------------
# Extras — not required, but this is where you'd otherwise be googling flags.
# ---------------------------------------------------------------------------

status: ## Show container state and health
	@$(COMPOSE) ps

logs: ## Follow the API logs
	$(COMPOSE) logs -f api

shell: ## Open a shell inside the API container
	$(COMPOSE) exec api /bin/bash

psql: ## Open psql against the containerised database
	$(COMPOSE) exec db psql -U save_some -d save_some

seed: ## Re-apply the sample data to a database that already exists
	@# initdb.d only runs on an empty volume, so re-seeding an existing database
	@# needs the file piped in explicitly.
	$(COMPOSE) exec -T db psql -U save_some -d save_some < backend/seed/local_seed.sql

reset-db: ## Drop the database volume and re-initialise from schema + seed
	$(COMPOSE) down db
	docker volume rm save-some_db-data 2>/dev/null || true
	$(COMPOSE) up -d --wait db

test-api: ## Hit the endpoints the app depends on
	@set -e; \
	base=http://127.0.0.1:$(API_PORT)/v1; \
	for path in /health /retailers/ /categories/ "/products/trending?limit=3"; do \
		printf '  %-34s ' "$$path"; \
		python3 -c "import sys,urllib.request,json; \
r=urllib.request.urlopen('$$base'+'''$$path''',timeout=15); d=json.loads(r.read()); \
print(r.status, (str(len(d))+' rows') if isinstance(d,list) else d)"; \
	done

nuke: ## Stop and remove containers, volumes and the image
	$(COMPOSE) down -v --remove-orphans
	-docker image rm $(IMAGE)
