output "table_name" {
  value = aws_dynamodb_table.observations.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}
