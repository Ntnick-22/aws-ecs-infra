# Long-lived layer: the identity CI uses. Never part of the nightly destroy,
# otherwise CI would delete the role it is running as.

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # Everything this project creates is prefixed, so IAM can be scoped to it
  project_roles = "arn:aws:iam::${local.account_id}:role/${var.name}-*"
}

# GitHub's token issuer. One per AWS account, shared by every repo.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# ---------- Infra repo: runs Terraform ----------

resource "aws_iam_role" "github_actions_infra" {
  name = "${var.name}-github-infra"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        # Any branch / PR of the infra repo may plan; applying is gated by the workflows.
        # Newer repos use GitHub's immutable subject (owner and repo IDs), so a deleted or
        # renamed repo name can't be re-created by someone else to get into this account.
        StringLike = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}@${var.github_owner_id}/${var.infra_repo}@${var.infra_repo_id}:*" }
      }
    }]
  })
}

# Everything except IAM and Organizations
resource "aws_iam_role_policy_attachment" "github_infra_power_user" {
  role       = aws_iam_role.github_actions_infra.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# The IAM that Terraform needs, limited to this project's roles
resource "aws_iam_role_policy" "github_infra_iam" {
  name = "iam-passrole"
  role = aws_iam_role.github_actions_infra.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole",
          "iam:UpdateRole", "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:ListInstanceProfilesForRole",
        ]
        Resource = local.project_roles
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider", "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
        ]
        Resource = aws_iam_openid_connect_provider.github.arn
      },
    ]
  })
}

# ---------- App repos: build, push to ECR, deploy to ECS ----------

resource "aws_iam_role" "github_actions_app" {
  name = "${var.name}-github-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Only the main branch of the app repos can deploy
          "token.actions.githubusercontent.com:sub" = [for repo in var.app_repos : "repo:${var.github_org}/${repo}:ref:refs/heads/main"]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_app_ecs" {
  name = "ecs-deploy"
  role = aws_iam_role.github_actions_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:UpdateService", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition", "ecs:ListTaskDefinitions"]
        Resource = "*"
      },
      {
        # Built from names, not references: the task roles live in layer 01, which is rebuilt nightly
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${var.name}-task-execution-role",
          "arn:aws:iam::${local.account_id}:role/${var.name}-task-role",
        ]
      },
      {
        # Login token is account-wide, so this one can't be scoped to a repo
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:aws:ecr:${var.region}:${local.account_id}:repository/${var.name}-*"
      }
    ]
  })
}
