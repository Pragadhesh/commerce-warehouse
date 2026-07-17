variable "metabase_endpoint" {
  type    = string
  default = "http://localhost:3000"
}

variable "metabase_username" {
  description = "Admin account created during Metabase's first-run setup wizard."
  type        = string
}

variable "metabase_password" {
  type      = string
  sensitive = true
}

variable "postgres_host" {
  description = "warehouse-db's address as seen from inside the compose network, not localhost."
  type        = string
  default     = "warehouse-db"
}

variable "postgres_port" {
  type    = number
  default = 5432
}

variable "postgres_db" {
  type    = string
  default = "commerce_warehouse"
}

variable "postgres_user" {
  type    = string
  default = "warehouse"
}

variable "postgres_password" {
  type      = string
  default   = "warehouse"
  sensitive = true
}
