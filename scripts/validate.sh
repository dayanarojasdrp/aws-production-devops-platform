#!/usr/bin/env sh
set -eu

terraform fmt -check -recursive terraform
