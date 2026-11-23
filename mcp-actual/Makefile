SERVICE := mcp-actual
VERSION := 1.15.1

.PHONY: build test up down logs restart upgrade

build:
	docker-compose build --build-arg ACTUAL_MCP_VERSION=$(VERSION)

test:
	# Smoke: binary loads (no module-load / syntax errors). actual-mcp has no
	# --help flag; with no env it will error on missing ACTUAL_SERVER_URL or
	# hang on stdio, both of which are fine — we only reject load-time failures.
	! timeout 5 docker run --rm local/actual-mcp:$(VERSION) 2>&1 | \
		grep -qE 'ERR_MODULE_NOT_FOUND|SyntaxError|Cannot find module'
	@echo "✓ binary loads"

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

restart:
	docker-compose up -d --force-recreate

upgrade:
	# Usage: make upgrade VERSION=1.15.2
	$(MAKE) build VERSION=$(VERSION)
	$(MAKE) test  VERSION=$(VERSION)
	$(MAKE) up

