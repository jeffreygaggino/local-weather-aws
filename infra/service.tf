# The always-on API: an ECS service keeping one serve task running, reachable on
# port 8080 from the IP that ran `terraform apply` and nowhere else.

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

resource "aws_security_group" "serve" {
  name        = "${local.name}-serve"
  description = "serve API"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "serve_from_me" {
  security_group_id = aws_security_group.serve.id
  description       = "API from the IP that ran terraform apply"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_vpc_security_group_egress_rule" "serve_out" {
  security_group_id = aws_security_group.serve.id
  description       = "ECR, CloudWatch Logs, DynamoDB"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

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
