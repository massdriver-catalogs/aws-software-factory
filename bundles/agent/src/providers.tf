terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.network.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = var.aws_authentication.external_id
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# Deployment tokens can't manage service accounts, so these resources use the
# credential's API key. The default provider stays on the deployment token.
provider "massdriver" {
  alias           = "admin"
  api_key         = try(var.massdriver.token, null)
  organization_id = try(var.massdriver.organization_id, null)
}
