#!/usr/bin/env sh
set -eu

terraform fmt -check -recursive terraform
docker compose config --quiet

docker run --rm \
  --volume "$(pwd)/app:/src" \
  --workdir /src \
  golang:1.24-alpine \
  sh -c 'test -z "$(gofmt -l .)" && go test ./...'
