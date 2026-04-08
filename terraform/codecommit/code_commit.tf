data "aws_caller_identity" "current" {
}

resource "aws_codecommit_repository" "main" {
  repository_name = "${local.name}-repo"
  default_branch  = "main"
  description     = "Repository for ${local.name}"
  tags = {
    Name = local.name
  }
}

resource "aws_codecommit_repository" "replica" {
  provider        = aws.use1
  repository_name = "${local.name}-repo-replica"
  default_branch  = "main"
  description     = "Replica repository for ${local.name} (mirrored from us-east-2)"
  tags = {
    Name = "${local.name}-replica"
  }
}

data "aws_iam_user" "drogers" {
  user_name = "drogers"
}

resource "aws_codecommit_approval_rule_template" "main_pr_requires_drogers" {
  name        = "${local.name}-main-pr-requires-drogers"
  description = "Require approval from drogers for pull requests targeting main."

  content = jsonencode({
    Version               = "2018-11-08"
    DestinationReferences = ["refs/heads/main"]
    Statements = [
      {
        Type                    = "Approvers"
        NumberOfApprovalsNeeded = 1
        ApprovalPoolMembers     = [data.aws_iam_user.drogers.arn]
      }
    ]
  })
}

resource "aws_codecommit_approval_rule_template_association" "main_repo_main_pr_requires_drogers" {
  approval_rule_template_name = aws_codecommit_approval_rule_template.main_pr_requires_drogers.name
  repository_name             = aws_codecommit_repository.main.repository_name
}

resource "aws_iam_user" "foo" {
  name = "code-commit-user-foo"
  tags = {
    Name = local.name
  }
}

resource "aws_iam_user_ssh_key" "foo" {
  username   = aws_iam_user.foo.name
  encoding   = "SSH"
  public_key = file("~/.ssh/id_chariot_github.pub")
}

resource "aws_iam_user_policy" "foo" {
  user = aws_iam_user.foo.name
  name = "code-commit-policy-foo"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:BatchGet*",
          "codecommit:BatchDescribe*",
          "codecommit:Get*",
          "codecommit:Describe*",
          "codecommit:GitPull",
          "codecommit:GitPush"
        ]
        Resource = aws_codecommit_repository.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:List*",
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_user" "dev" {
  name = "code-commit-dev-user"
  tags = {
    Name = local.name
  }
}

resource "aws_iam_user_ssh_key" "dev" {
  username   = aws_iam_user.dev.name
  encoding   = "SSH"
  public_key = file("./dev_rsa.pub")
}

data "aws_iam_policy_document" "dev_codecommit_deny_protected_branches" {
  statement {
    effect = "Deny"

    actions = [
      "codecommit:GitPush",
      "codecommit:DeleteBranch",
      "codecommit:PutFile",
      "codecommit:MergeBranchesByFastForward",
      "codecommit:MergeBranchesBySquash",
      "codecommit:MergeBranchesByThreeWay",
      "codecommit:MergePullRequestByFastForward",
      "codecommit:MergePullRequestBySquash",
      "codecommit:MergePullRequestByThreeWay",
    ]

    resources = [
      "arn:aws:codecommit:${local.region}:${data.aws_caller_identity.current.account_id}:${aws_codecommit_repository.main.repository_name}"
    ]

    condition {
      test     = "StringEqualsIfExists"
      variable = "codecommit:References"
      values = [
        "refs/heads/main",
        "refs/heads/prod",
      ]
    }

    condition {
      test     = "Null"
      variable = "codecommit:References"
      values   = ["false"]
    }
  }
}

resource "aws_iam_user_policy" "dev" {
  user   = aws_iam_user.dev.name
  name   = "code-commit-policy-dev"
  policy = data.aws_iam_policy_document.dev_codecommit_deny_protected_branches.json
}

resource "aws_iam_user_policy" "dev_allow" {
  user = aws_iam_user.dev.name
  name = "code-commit-policy-dev-allow"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:BatchGet*",
          "codecommit:BatchDescribe*",
          "codecommit:Get*",
          "codecommit:Describe*",
          "codecommit:List*",
          "codecommit:GitPull",
          "codecommit:GitPush",
          "codecommit:CreatePullRequest"
        ]
        Resource = aws_codecommit_repository.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:List*",
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_user" "rep" {
  name = "code-commit-rep-user"
  tags = {
    Name = local.name
  }
}

resource "aws_iam_user_policy" "rep" {
  user = aws_iam_user.rep.name
  name = "code-commit-policy-rep"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:BatchGet*",
          "codecommit:BatchDescribe*",
          "codecommit:Get*",
          "codecommit:Describe*",
          "codecommit:List*",
          "codecommit:GitPull",
          "codecommit:GitPush"
        ]
        Resource = aws_codecommit_repository.replica.arn
      }
    ]
  })
}

resource "aws_sns_topic" "pr-topic" {
  name = "${local.name}-codecommit-pr-topic"
}

resource "aws_sns_topic" "all-main-topic" {
  name = "${local.name}-codecommit-all-main-topic"
}

data "aws_iam_policy_document" "codecommit-topic-policy" {
  statement {
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["codestar-notifications.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.pr-topic.arn,
    ]
  }
}

data "aws_iam_policy_document" "codecommit-all-main-topic-policy" {
  statement {
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["codecommit.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.all-main-topic.arn
    ]
  }
}

resource "aws_sns_topic_policy" "pr-topic-policy" {
  arn    = aws_sns_topic.pr-topic.arn
  policy = data.aws_iam_policy_document.codecommit-topic-policy.json
}

resource "aws_sns_topic_policy" "all-main-topic-policy" {
  arn    = aws_sns_topic.all-main-topic.arn
  policy = data.aws_iam_policy_document.codecommit-all-main-topic-policy.json
}

resource "aws_codestarnotifications_notification_rule" "foo-code-repo-commits-rule" {
  detail_type = "FULL"
  event_type_ids = [
    "codecommit-repository-comments-on-commits",
    "codecommit-repository-pull-request-created",
    "codecommit-repository-pull-request-merged"
  ]

  name     = "${local.name}-code-repo-commits"
  resource = aws_codecommit_repository.main.arn

  target {
    address = aws_sns_topic.pr-topic.arn
  }

  depends_on = [
    aws_sns_topic_policy.pr-topic-policy,
  ]
}

resource "aws_codecommit_trigger" "foo-code-repo-commits-trigger" {
  repository_name = aws_codecommit_repository.main.repository_name

  trigger {
    name            = "main-all-events"
    events          = ["all"]
    branches        = ["main"]
    destination_arn = aws_sns_topic.all-main-topic.arn
  }

  trigger {
    name            = "mirror-ref-events"
    events          = ["createReference", "updateReference"]
    destination_arn = aws_lambda_function.codecommit_mirror.arn
  }

  depends_on = [
    aws_sns_topic_policy.all-main-topic-policy,
  ]
}

#-----------------------------------------------------------
# Outputs
#-----------------------------------------------------------
output "repository_url" {
  value = aws_codecommit_repository.main.clone_url_http
}

output "clone_url_ssh" {
  value = aws_codecommit_repository.main.clone_url_ssh
}

output "repository_id" {
  value = aws_codecommit_repository.main.repository_id
}

output "replica_repository_url" {
  value = aws_codecommit_repository.replica.clone_url_http
}

output "replica_clone_url_ssh" {
  value = aws_codecommit_repository.replica.clone_url_ssh
}

output "replica_repository_id" {
  value = aws_codecommit_repository.replica.repository_id
}
