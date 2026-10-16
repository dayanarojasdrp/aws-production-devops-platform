mock_provider "aws" {}

variables {
  repository_name = "test-platform-dev-api"
  max_image_count = 20
  force_delete    = true
}

run "development_repository" {
  command = apply

  assert {
    condition     = aws_ecr_repository.this.name == "test-platform-dev-api"
    error_message = "The repository name must identify the application and environment."
  }

  assert {
    condition     = aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE"
    error_message = "Image tags must be immutable so a Git SHA cannot be overwritten."
  }

  assert {
    condition     = one(aws_ecr_repository.this.image_scanning_configuration).scan_on_push == true
    error_message = "Basic vulnerability scanning must run whenever an image is pushed."
  }

  assert {
    condition     = one(aws_ecr_repository.this.encryption_configuration).encryption_type == "AES256"
    error_message = "Repository images must use ECR managed server-side encryption."
  }

  assert {
    condition     = aws_ecr_repository.this.force_delete == true
    error_message = "Development must support intentional cleanup even when test images remain."
  }

  assert {
    condition = (
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].selection.tagStatus == "any" &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].selection.countType == "imageCountMoreThan" &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].selection.countNumber == 20 &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].action.type == "expire"
    )
    error_message = "The lifecycle policy must expire images beyond the development retention count."
  }
}

run "production_repository" {
  command = apply

  variables {
    repository_name = "test-platform-prod-api"
    max_image_count = 50
    force_delete    = false
  }

  assert {
    condition     = aws_ecr_repository.this.force_delete == false
    error_message = "Production must refuse deletion while images remain."
  }

  assert {
    condition     = jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].selection.countNumber == 50
    error_message = "Production must retain the larger image history configured for rollback."
  }
}
