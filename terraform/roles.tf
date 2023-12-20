resource "aws_iam_role" "app_exec" {
  name               = "${var.app_name}-exec"
  description        = "ECS Fargate execution role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role_policy.json
}

data "aws_iam_policy_document" "app_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "app_exec" {
  role       = aws_iam_role.app_exec.name
  policy_arn = aws_iam_policy.app_exec.arn
}

resource "aws_iam_policy" "app_exec" {
  name   = "${var.app_name}-exec"
  policy = data.aws_iam_policy_document.app_exec.json
}

data "aws_iam_policy_document" "app_exec" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "secretsmanager:GetSecretValue"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = ["aws:sourceVpc"]
      variable = data.aws_vpc.app.id
    }
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::prod-${data.aws_region.current.name}-starport-layer-bucket/*"]
  }
}

output "name" {
  value = data.aws_region.current.name
}

resource "aws_iam_role" "app_task" {
  name               = "${var.app_name}-task"
  description        = "Default ECS Fargate task role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "api_task_logs" {
  role       = aws_iam_role.api_task.name
  policy_arn = aws_iam_policy.task_logs.arn
}

resource "aws_iam_role_policy_attachment" "task_logs" {
  role       = aws_iam_role.app_task.name
  policy_arn = aws_iam_policy.task_logs.arn
}

resource "aws_iam_policy" "task_logs" {
  name        = "${var.app_name}-task-logs"
  description = "Allows Fargate task logging"
  policy      = data.aws_iam_policy_document.logs.json
}

data "aws_iam_policy_document" "logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "task_ecs_exec" {
  role       = aws_iam_role.app_task.name
  policy_arn = aws_iam_policy.task_ecs_exec.arn
}

resource "aws_iam_policy" "task_ecs_exec" {
  name        = "${var.app_name}-task-ecs-exec"
  description = "Allows ECS Exec for Fargate tasks"
  policy      = data.aws_iam_policy_document.task_ecs_exec.json
}

data "aws_iam_policy_document" "task_ecs_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}
