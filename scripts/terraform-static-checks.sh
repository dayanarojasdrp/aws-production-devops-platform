#!/usr/bin/env sh
set -eu

terraform_bin="${TERRAFORM_BIN:-terraform}"

"${terraform_bin}" fmt -check -recursive terraform

terraform_roots="
terraform/bootstrap
terraform/modules/networking
terraform/modules/security
terraform/modules/rds
terraform/modules/ecr
terraform/modules/alb
terraform/modules/ecs
terraform/environments/dev
terraform/environments/prod
"

for directory in ${terraform_roots}; do
  echo "Initializing ${directory} without its backend"
  if [ -f "${directory}/.terraform.lock.hcl" ]; then
    "${terraform_bin}" -chdir="${directory}" init -backend=false -input=false -lockfile=readonly
  else
    "${terraform_bin}" -chdir="${directory}" init -backend=false -input=false
  fi
  "${terraform_bin}" -chdir="${directory}" validate
done

test_modules="
networking
security
rds
ecr
alb
ecs
"

for module in ${test_modules}; do
  echo "Testing terraform/modules/${module}"
  "${terraform_bin}" -chdir="terraform/modules/${module}" test
done
