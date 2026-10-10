resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = 3
}

resource "aws_ecs_cluster" "main" {
  name = local.name
}

# The blueprint for every mode. The default command is serve; collect and check
# override it when they're run.
resource "aws_ecs_task_definition" "app" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      environment = [
        { name = "TABLE", value = aws_dynamodb_table.observations.name },
        { name = "LOCATION", value = var.location.slug },
        { name = "LATITUDE", value = tostring(var.location.latitude) },
        { name = "LONGITUDE", value = tostring(var.location.longitude) },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}
