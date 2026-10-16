.PHONY: up down logs fmt validate smoke-test load-test bootstrap-init bootstrap-validate bootstrap-plan network-test security-test rds-test ecr-test

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

network-test:
	terraform -chdir=terraform/modules/networking init -backend=false
	terraform -chdir=terraform/modules/networking test

security-test:
	terraform -chdir=terraform/modules/security init -backend=false
	terraform -chdir=terraform/modules/security test

rds-test:
	terraform -chdir=terraform/modules/rds init -backend=false
	terraform -chdir=terraform/modules/rds test

ecr-test:
	terraform -chdir=terraform/modules/ecr init -backend=false
	terraform -chdir=terraform/modules/ecr test
