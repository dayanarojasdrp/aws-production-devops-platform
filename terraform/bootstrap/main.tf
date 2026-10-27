provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Stack     = "bootstrap"
    })
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  github_repository_subject = var.github_owner_id != null && var.github_repository_id != null ? format(
    "repo:%s@%s/%s@%s",
    var.github_owner,
    var.github_owner_id,
    var.github_repository,
    var.github_repository_id,
    ) : format(
    "repo:%s/%s",
    var.github_owner,
    var.github_repository,
  )
  github_subject = "${local.github_repository_subject}:ref:refs/heads/${var.github_branch}"

  deployment_environments = {
    dev  = var.github_deployment_environments.development
    prod = var.github_deployment_environments.production
  }

  deployment_targets = {
    for environment, github_environment in local.deployment_environments : environment => {
      github_environment = github_environment
      github_subject     = "${local.github_repository_subject}:environment:${github_environment}"
      name_prefix        = "${var.project_name}-${environment}"
    }
  }

  state_keys = [
    "dev/terraform.tfstate",
    "prod/terraform.tfstate",
  ]
  state_object_arns = [for key in local.state_keys : "${aws_s3_bucket.terraform_state.arn}/${key}"]
  lock_object_arns  = [for key in local.state_keys : "${aws_s3_bucket.terraform_state.arn}/${key}.tflock"]
}

check "github_identity_ids" {
  assert {
    condition     = (var.github_owner_id == null) == (var.github_repository_id == null)
    error_message = "github_owner_id and github_repository_id must either both be set or both be null."
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.state_bucket.json
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "github-actions"
  }
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    sid     = "GitHubActionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_subject]
    }
  }
}

resource "aws_iam_role" "github_terraform" {
  name                 = "${var.project_name}-github-terraform"
  description          = "Short-lived AWS access for this repository's Terraform workflows."
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_terraform_state_access" {
  statement {
    sid       = "ListStatePrefixes"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["dev/*", "prod/*"]
    }
  }

  statement {
    sid    = "ReadWriteStateAndLocks"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = concat(local.state_object_arns, local.lock_object_arns)
  }

  statement {
    sid       = "DeleteLockFilesOnly"
    effect    = "Allow"
    actions   = ["s3:DeleteObject"]
    resources = local.lock_object_arns
  }
}

resource "aws_iam_role_policy" "github_terraform_state_access" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_terraform.id
  policy = data.aws_iam_policy_document.github_terraform_state_access.json
}

data "aws_iam_policy_document" "github_deployment_assume_role" {
  for_each = local.deployment_targets

  statement {
    sid     = "GitHubEnvironmentAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value.github_subject]
    }
  }
}

resource "aws_iam_role" "github_deployment" {
  for_each = local.deployment_targets

  name                 = "${var.project_name}-github-deploy-${each.key}"
  description          = "Short-lived ${each.key} deployment access for this repository's GitHub Environment."
  assume_role_policy   = data.aws_iam_policy_document.github_deployment_assume_role[each.key].json
  max_session_duration = 3600

  tags = {
    Environment = each.key
  }
}

data "aws_iam_policy_document" "github_deployment" {
  for_each = local.deployment_targets

  statement {
    sid       = "GetEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PublishAndReadApplicationImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${each.value.name_prefix}-api",
    ]
  }

  statement {
    sid     = "ReadApplicationTaskDefinitions"
    effect  = "Allow"
    actions = ["ecs:DescribeTaskDefinition"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${each.value.name_prefix}-api:*",
    ]
  }

  # RegisterTaskDefinition creates the revision, so AWS evaluates this action
  # before a resource ARN exists and requires a wildcard resource.
  statement {
    sid       = "RegisterTaskDefinitionRevision"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid    = "DeployOnlyTheApplicationService"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${each.value.name_prefix}/${each.value.name_prefix}-api",
    ]
  }

  statement {
    sid     = "PassOnlyApplicationTaskRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.name_prefix}-ecs-execution",
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${each.value.name_prefix}-ecs-task",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deployment" {
  for_each = local.deployment_targets

  name   = "deploy-${each.key}-application"
  role   = aws_iam_role.github_deployment[each.key].id
  policy = data.aws_iam_policy_document.github_deployment[each.key].json
}
