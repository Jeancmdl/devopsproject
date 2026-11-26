COMPOSE ?= docker compose

.PHONY: secrets up down logs ps bootstrap bootstrap-dry-run lint

secrets: ## Create .env with random secrets (only if it does not exist)
	@if [ -f .env ]; then echo ".env already exists, not overwriting"; else \
	  cp .env.example .env && \
	  sed -i "0,/__GENERATE__/s//$$(openssl rand -hex 24)/" .env && \
	  sed -i "0,/__GENERATE__/s//$$(openssl rand -hex 24)/" .env && \
	  sed -i "0,/__GENERATE__/s##$$(head -c32 /dev/urandom | base64)#" .env && \
	  chmod 600 .env && echo ".env created. Admin password: grep SEMAPHORE_ADMIN_PASSWORD .env"; \
	fi

up: ## Start Semaphore
	$(COMPOSE) up -d

down: ## Stop Semaphore
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f semaphore

ps:
	$(COMPOSE) ps

bootstrap-dry-run: ## Show what would be created in Semaphore
	python3 scripts/bootstrap.py --config config/semaphore.json --dry-run

bootstrap: ## Create project, keys, repo, inventories and templates via API
	python3 scripts/bootstrap.py --config config/semaphore.json

lint:
	ruff check scripts
	$(COMPOSE) config -q
