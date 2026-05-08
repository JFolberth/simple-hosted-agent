terraform {
  required_version = ">= 1.9"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Local state — suitable for development and CI where state is not shared.
  # Switch to a remote backend (e.g. azurerm) for team or production deployments.
  backend "local" {}
}

provider "azapi" {}
