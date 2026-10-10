# The always-on API: an ECS service keeping one serve task running.

resource "aws_ecs_service" "serve" {
  name            = "${local.name}-serve"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.serve.id]
    assign_public_ip = true
  }
}
