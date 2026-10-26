terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.4"
    }
  }
}

provider "github" {
  owner = var.github.owner
  app_auth {
    id              = var.github.app_id
    installation_id = var.github.installation_id
    pem_file        = var.github.private_key
  }
}

# IAM is global; without a registry the region only satisfies the provider.
provider "aws" {
  region = try(var.registry.region, "us-east-1")
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
