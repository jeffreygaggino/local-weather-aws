# Alarms email through SNS. AWS sends a confirmation link to alert_email each time the
# subscription is created (every Session); nothing is delivered until it's clicked.

resource "aws_sns_topic" "alarms" {
  name = "${local.name}-alarms"
}

resource "aws_sns_topic_subscription" "alarms_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Observation Age, published by the Watchdog every 15 minutes.
#   ALARM             -> over 35 minutes: two collect runs in a row produced nothing
#   INSUFFICIENT_DATA -> no reading at all: the Watchdog itself has stopped
#   OK                -> back to normal
# Missing data counts as "missing" rather than "breaching": a new alarm has no data yet,
# and "breaching" would send a false alarm on every `make tf-apply`.
resource "aws_cloudwatch_metric_alarm" "observation_stale" {
  alarm_name        = "${local.name}-observation-stale"
  alarm_description = "No new Observation for ${var.location.slug} in 35 minutes, or the Watchdog has stopped reporting."

  namespace   = local.metric_namespace
  metric_name = "ObservationAgeMinutes"
  dimensions = {
    Location = var.location.slug
  }
  statistic           = "Maximum"
  period              = 900
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 35
  treat_missing_data  = "missing"

  alarm_actions             = [aws_sns_topic.alarms.arn]
  insufficient_data_actions = [aws_sns_topic.alarms.arn]
  ok_actions                = [aws_sns_topic.alarms.arn]
}

# Anything in the dead-letter queue means the scheduler couldn't start a task.
resource "aws_cloudwatch_metric_alarm" "scheduler_dlq" {
  alarm_name        = "${local.name}-scheduler-dlq"
  alarm_description = "EventBridge Scheduler failed to start a task. See why with `make dlq`."

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = aws_sqs_queue.scheduler_dlq.name
  }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
}
