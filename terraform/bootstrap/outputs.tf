output "state_bucket_name" {
  description = "S3 bucket used by the development and production Terraform backends."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN that GitHub Actions assumes through OIDC."
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_oidc_subject" {
  description = "Exact GitHub OIDC subject accepted by the role trust policy."
  value       = local.github_subject
}
