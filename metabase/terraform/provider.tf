terraform {
  required_version = ">= 1.5"

  required_providers {
    metabase = {
      source  = "flovouin/metabase"
      version = "~> 1.0"
    }
  }
}

provider "metabase" {
  endpoint = var.metabase_endpoint
  username = var.metabase_username
  password = var.metabase_password
}
