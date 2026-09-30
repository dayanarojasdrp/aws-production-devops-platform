terraform {
  backend "s3" {
    key          = "dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
