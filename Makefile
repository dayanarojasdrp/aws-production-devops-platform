.PHONY: up down logs fmt validate smoke-test load-test

up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f

fmt:
	terraform fmt -recursive terraform

validate:
	./scripts/validate.sh

smoke-test:
	./scripts/smoke-test.sh

load-test:
	./scripts/load-test.sh
