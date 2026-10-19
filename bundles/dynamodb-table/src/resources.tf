# Consumers bind access by attaching one of these policy ARNs to their own
# role (aws_iam_role_policy_attachment), so the table owns its permissions.
resource "massdriver_resource" "table" {
  field = "table"
  name  = "DynamoDB ${local.name}"
  resource = jsonencode(merge(
    {
      name          = aws_dynamodb_table.main.name
      arn           = aws_dynamodb_table.main.arn
      region        = var.region
      partition_key = var.partition_key
      policies = [
        { name = "read-write", arn = aws_iam_policy.read_write.arn },
        { name = "read", arn = aws_iam_policy.read.arn },
      ]
    },
    local.has_sort_key ? { sort_key = var.sort_key } : {},
  ))
}
