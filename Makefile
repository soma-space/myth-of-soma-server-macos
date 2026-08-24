SHELL := /bin/bash

.PHONY: doctor fetch vm-start db-up db-restore db-status db-down crossover prepare services start stop status smoke account client-fetch client-setup client

doctor:
	./scripts/doctor.sh

fetch:
	./scripts/fetch-server.sh

vm-start:
	./scripts/start-colima.sh

db-up:
	@test -f .env || (echo "Copy .env.example to .env and change MSSQL_SA_PASSWORD first." >&2; exit 1)
	docker-compose up -d mssql

db-restore:
	./scripts/restore-database.sh

db-status:
	docker-compose ps

db-down:
	docker-compose down

crossover:
	./scripts/setup-crossover.sh

prepare:
	./scripts/prepare-runtime.sh

services:
	./scripts/configure-services.sh

start:
	./scripts/start-game-server.sh

stop:
	./scripts/stop-game-server.sh

status:
	./scripts/status.sh

smoke:
	./scripts/smoke-test.sh

account:
	./scripts/create-account.sh "$(SOMA_ACCOUNT_USER)" "$(SOMA_ACCOUNT_PASSWORD)" "$(SOMA_ACCOUNT_EMAIL)"

client-fetch:
	./scripts/fetch-client.sh

client-setup:
	./scripts/setup-client.sh

client:
	./scripts/launch-client.sh
