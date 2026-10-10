# Public subnets only, no NAT gateway: tasks get a public IP and reach AWS services
# and Open-Meteo through the internet gateway.

# Subnets give addresses, the route table points the way out, the internet gateway is the way out, the association links each subnet to the route table, and the public IP lets replies come back. Remove any one of them and the task can't pull its image.

locals {
  public_subnets = {
    "ap-southeast-2a" = "10.0.0.0/24"
    "ap-southeast-2b" = "10.0.1.0/24"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = local.name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.name
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${local.name}-public-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Security groups (firewalls on each task's network card)

# serve: port 8080 from the IP that ran `terraform apply` and nowhere else.
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

# Scheduled jobs: outbound only.
resource "aws_security_group" "jobs" {
  name        = "${local.name}-jobs"
  description = "Scheduled jobs: outbound only"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "jobs_out" {
  security_group_id = aws_security_group.jobs.id
  description       = "Open-Meteo, ECR, CloudWatch Logs, DynamoDB"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
