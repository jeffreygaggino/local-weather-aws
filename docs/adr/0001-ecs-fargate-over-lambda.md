# ECS Fargate over Lambda for scheduled jobs

Collecting an Observation and running the Watchdog are each a few seconds of work every 15 minutes, which is a textbook Lambda workload. We run them as one-off ECS Fargate tasks from an image in ECR instead, because the point of this project is hands-on experience with ECR, ECS Fargate and EventBridge Scheduler's ECS target. Don't "simplify" these jobs into Lambdas: that would remove the thing the project exists to practise.

## Consequences

- Each run pays Fargate's 1-minute minimum and 30-60s cold start, which is why schedules are offset a couple of minutes into each Slot.
- Tasks need a public IP to reach ECR, DynamoDB and CloudWatch without a NAT gateway.
- Scheduler needs `iam:PassRole` on both task roles; a missing grant fails silently, hence the dead-letter queue.
