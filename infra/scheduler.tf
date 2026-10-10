# EventBridge Scheduler runs two jobs as Fargate tasks:
#   collect  -> just after each Open-Meteo Slot opens
#   watchdog -> midway between collect runs, so a healthy Observation Age is about 9 minutes
# Failed attempts to start a task land in the dead-letter queue.

locals {
  scheduled_jobs = {
    collect  = { cron = "cron(2/15 * * * ? *)", command = ["node", "src/collect.ts"] }
    watchdog = { cron = "cron(9/15 * * * ? *)", command = ["node", "src/check.ts"] }
  }
}

resource "aws_sqs_queue" "scheduler_dlq" {
  name                      = "${local.name}-scheduler-dlq"
  message_retention_seconds = 345600 # 4 days
}

resource "aws_scheduler_schedule" "job" {
  for_each = local.scheduled_jobs

  name                         = "${local.name}-${each.key}"
  schedule_expression          = each.value.cron
  schedule_expression_timezone = "Australia/Brisbane"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.main.arn
    role_arn = aws_iam_role.scheduler.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.app.arn
      launch_type         = "FARGATE"

      network_configuration {
        subnets          = [for subnet in aws_subnet.public : subnet.id]
        security_groups  = [aws_security_group.jobs.id]
        assign_public_ip = true
      }
    }

    input = jsonencode({
      containerOverrides = [
        { name = "app", command = each.value.command }
      ]
    })

    retry_policy {
      maximum_retry_attempts       = 2
      maximum_event_age_in_seconds = 300
    }

    dead_letter_config {
      arn = aws_sqs_queue.scheduler_dlq.arn
    }
  }
}
