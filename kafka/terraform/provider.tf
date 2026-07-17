terraform {
  required_version = ">= 1.5"

  required_providers {
    kafka = {
      source  = "Mongey/kafka"
      version = "~> 0.5"
    }
  }
}

provider "kafka" {
  bootstrap_servers = [var.kafka_bootstrap_servers]
  tls_enabled       = false
}
