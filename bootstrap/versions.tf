terraform {
  required_version = ">= 1.5"

  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.4"
    }
  }
}

provider "massdriver" {}
