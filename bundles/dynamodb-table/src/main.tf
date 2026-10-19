locals {
  name         = var.md_metadata.name_prefix
  has_sort_key = try(var.sort_key.name, "") != ""
  has_ttl      = var.ttl_attribute != ""
}

resource "aws_dynamodb_table" "main" {
  name                        = local.name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = var.partition_key.name
  range_key                   = local.has_sort_key ? var.sort_key.name : null
  table_class                 = var.table_class
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = var.partition_key.name
    type = var.partition_key.type
  }

  dynamic "attribute" {
    for_each = local.has_sort_key ? [var.sort_key] : []
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  ttl {
    enabled        = local.has_ttl
    attribute_name = local.has_ttl ? var.ttl_attribute : ""
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }
}

resource "aws_iam_policy" "read" {
  name        = "${local.name}-read"
  description = "Read items from the ${local.name} DynamoDB table"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:BatchGetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:DescribeTable",
        "dynamodb:ConditionCheckItem",
      ]
      Resource = [aws_dynamodb_table.main.arn, "${aws_dynamodb_table.main.arn}/index/*"]
    }]
  })
}

resource "aws_iam_policy" "read_write" {
  name        = "${local.name}-read-write"
  description = "Read and write items in the ${local.name} DynamoDB table"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:BatchGetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:DescribeTable",
        "dynamodb:ConditionCheckItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:BatchWriteItem",
      ]
      Resource = [aws_dynamodb_table.main.arn, "${aws_dynamodb_table.main.arn}/index/*"]
    }]
  })
}
