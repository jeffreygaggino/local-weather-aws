# execution role -> used by ECS to start a task: pull the image from ECR, write logs
# task role      -> used by our code while it runs: read and write the Observations table
# scheduler role -> used by EventBridge Scheduler to start the collect and Watchdog tasks

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

  # PutMetricData can't be limited to a resource, so it's limited to our namespace instead.
  statement {
    sid       = "ObservationAgeMetric"
    actions   = ["cloudwatch:PutMetricData"] # check
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = [local.metric_namespace]
    }
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "observations"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}

# Scheduler role: lets EventBridge Scheduler start the scheduled tasks

data "aws_iam_policy_document" "scheduler_can_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_can_assume.json
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    sid       = "StartTasks"
    actions   = ["ecs:RunTask"]
    resources = ["${aws_ecs_task_definition.app.arn_without_revision}:*"]
  }

  # Starting a task hands it the execution and task roles.
  statement {
    sid       = "HandRolesToTasks"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
  }

  statement {
    sid       = "ReportFailures"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.scheduler_dlq.arn]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "run-scheduled-tasks"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}
