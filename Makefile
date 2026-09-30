.PHONY: up down logs fmt validate smoke-test load-test bootstrap-init bootstrap-validate bootstrap-plan

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

bootstrap-init:
	terraform -chdir=terraform/bootstrap init

bootstrap-validate:
	terraform -chdir=terraform/bootstrap fmt -check
	terraform -chdir=terraform/bootstrap validate

bootstrap-plan:
	terraform -chdir=terraform/bootstrap plan -out=bootstrap.tfplan
