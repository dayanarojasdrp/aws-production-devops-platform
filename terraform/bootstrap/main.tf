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

locals {
  github_subject = var.github_owner_id != null && var.github_repository_id != null ? format(
    "repo:%s@%s/%s@%s:ref:refs/heads/%s",
    var.github_owner,
    var.github_owner_id,
    var.github_repository,
    var.github_repository_id,
    var.github_branch,
    ) : format(
    "repo:%s/%s:ref:refs/heads/%s",
    var.github_owner,
    var.github_repository,
    var.github_branch,
  )

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
    bucket_key_enabled = true
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

resource "aws_iam_role" "github_actions" {
  name                 = "${var.project_name}-github-actions"
  description          = "Short-lived AWS access for this repository's GitHub Actions workflow."
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_state_access" {
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

resource "aws_iam_role_policy" "github_state_access" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_state_access.json
}
