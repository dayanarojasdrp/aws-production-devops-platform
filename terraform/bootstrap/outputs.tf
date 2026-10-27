output "aws_account_id" {
  description = "AWS account that owns the bootstrap resources."
  value       = data.aws_caller_identity.current.account_id
}

output "state_bucket_name" {
  description = "S3 bucket used by the development and production Terraform backends."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "github_terraform_role_arn" {
  description = "IAM role ARN that GitHub Terraform workflows assume through OIDC."
  value       = aws_iam_role.github_terraform.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_oidc_subject" {
  description = "Exact GitHub OIDC subject accepted by the role trust policy."
  value       = local.github_subject
}

output "github_deployment_role_arns" {
  description = "Environment-specific IAM role ARNs assumed by the application deployment workflow."
  value = {
    for environment, role in aws_iam_role.github_deployment : environment => role.arn
  }
}

output "github_deployment_oidc_subjects" {
  description = "Exact GitHub Environment OIDC subjects accepted by the deployment roles."
  value = {
    for environment, target in local.deployment_targets : environment => target.github_subject
  }
}

output "aws_region" {
  description = "AWS region configured for bootstrap and backend resources."
  value       = var.aws_region
}
