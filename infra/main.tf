locals {
  name             = "local-weather"
  metric_namespace = "LocalWeather"
}

# Same keys as app/scripts/create-local-table.ts; the two must stay in step.
resource "aws_dynamodb_table" "observations" {
  name         = "${local.name}-observations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "location"
  range_key    = "ts"

  attribute {
    name = "location"
    type = "S"
  }

  attribute {
    name = "ts"
    type = "S"
  }
}

resource "aws_ecr_repository" "app" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"
  # Lets `terraform destroy` remove the repository while it still holds images.
  force_delete = true
}
