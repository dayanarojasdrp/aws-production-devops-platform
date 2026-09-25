.PHONY: fmt validate smoke-test load-test

fmt:
	terraform fmt -recursive terraform

validate:
	./scripts/validate.sh

smoke-test:
	./scripts/smoke-test.sh

load-test:
	./scripts/load-test.sh
