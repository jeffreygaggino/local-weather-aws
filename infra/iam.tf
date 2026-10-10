# Two roles, two jobs:
#   execution role -> used by ECS to start the task: pull the image from ECR, write logs
#   task role      -> used by our code while it runs: read and write the Observations table

data "aws_iam_policy_document" "ecs_tasks_can_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_can_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role

resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_can_assume.json
}

data "aws_iam_policy_document" "task" {
  statement {
    sid = "Observations"
    actions = [
      "dynamodb:PutItem",       # collect
      "dynamodb:Query",         # serve, check
      "dynamodb:DescribeTable", # check (Session start)
    ]
    resources = [aws_dynamodb_table.observations.arn]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "observations"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}
