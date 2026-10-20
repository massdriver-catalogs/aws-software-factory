data "aws_caller_identity" "current" {}

locals {
  name = var.md_metadata.name_prefix
  kms  = var.encryption == "KMS"
}

resource "aws_kms_key" "images" {
  count               = local.kms ? 1 : 0
  description         = "${local.name} container images"
  enable_key_rotation = true
}

resource "aws_ecr_repository" "main" {
  name                 = local.name
  image_tag_mutability = var.tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = local.kms ? "KMS" : "AES256"
    kms_key         = local.kms ? aws_kms_key.images[0].arn : null
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest ${var.keep_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_images
        }
        action = { type = "expire" }
      },
    ]
  })
}

resource "aws_ecr_repository_policy" "lambda_pull" {
  repository = aws_ecr_repository.main.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaPull"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
      Condition = {
        StringLike = { "aws:sourceArn" = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:*" }
      }
    }]
  })
}

resource "aws_iam_policy" "push" {
  name        = "${local.name}-push"
  description = "Push images to the ${local.name} ECR repository"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = aws_ecr_repository.main.arn
      },
    ]
  })
}

resource "aws_iam_policy" "pull" {
  name        = "${local.name}-pull"
  description = "Pull images from the ${local.name} ECR repository"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = aws_ecr_repository.main.arn
      },
    ]
  })
}
