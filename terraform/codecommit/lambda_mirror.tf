resource "aws_ecr_repository" "codecommit_mirror" {
  name                 = "${local.name}-codecommit-mirror"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = local.name
  }
}

data "aws_iam_policy_document" "codecommit_mirror_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codecommit_mirror" {
  name               = "${local.name}-codecommit-mirror"
  assume_role_policy = data.aws_iam_policy_document.codecommit_mirror_assume_role.json
  tags = {
    Name = local.name
  }
}

data "aws_iam_policy_document" "codecommit_mirror_role_policy" {
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid = "EcrAuth"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid = "EcrPullImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = [aws_ecr_repository.codecommit_mirror.arn]
  }

  statement {
    sid = "ReadSourceRepo"
    actions = [
      "codecommit:GitPull",
      "codecommit:GetRepository"
    ]
    resources = [aws_codecommit_repository.main.arn]
  }

  statement {
    sid = "WriteReplicaRepo"
    actions = [
      "codecommit:GitPush",
      "codecommit:GetRepository"
    ]
    resources = [aws_codecommit_repository.replica.arn]
  }
}

resource "aws_iam_role_policy" "codecommit_mirror" {
  name   = "${local.name}-codecommit-mirror"
  role   = aws_iam_role.codecommit_mirror.id
  policy = data.aws_iam_policy_document.codecommit_mirror_role_policy.json
}

data "aws_ecr_image" "codecommit_mirror" {
  repository_name = aws_ecr_repository.codecommit_mirror.name
  image_tag       = "latest"
}

resource "aws_lambda_function" "codecommit_mirror" {
  function_name = "${local.name}-codecommit-mirror"
  role          = aws_iam_role.codecommit_mirror.arn

  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.codecommit_mirror.repository_url}@${data.aws_ecr_image.codecommit_mirror.image_digest}"
  architectures = ["x86_64"]

  timeout     = 900
  memory_size = 1024

  reserved_concurrent_executions = 1

  ephemeral_storage {
    size = 4096
  }

  environment {
    variables = {
      SOURCE_REGION     = local.region
      SOURCE_REPO_NAME  = aws_codecommit_repository.main.repository_name
      REPLICA_REGION    = "us-east-1"
      REPLICA_REPO_NAME = aws_codecommit_repository.replica.repository_name
    }
  }

  depends_on = [aws_iam_role_policy.codecommit_mirror]
}

resource "aws_lambda_permission" "allow_codecommit_invoke_mirror" {
  statement_id  = "AllowExecutionFromCodeCommit"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.codecommit_mirror.function_name
  principal     = "codecommit.amazonaws.com"
  source_arn    = aws_codecommit_repository.main.arn
}

resource "aws_codecommit_trigger" "mirror" {
  repository_name = aws_codecommit_repository.main.repository_name

  trigger {
    name            = "mirror-ref-events"
    events          = ["createReference", "updateReference"]
    destination_arn = aws_lambda_function.codecommit_mirror.arn
  }

  depends_on = [aws_lambda_permission.allow_codecommit_invoke_mirror]
}

