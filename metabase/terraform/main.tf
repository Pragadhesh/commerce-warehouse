resource "metabase_database" "warehouse" {
  name   = "commerce-warehouse"
  engine = "postgres"

  details = {
    host     = var.postgres_host
    port     = var.postgres_port
    dbname   = var.postgres_db
    user     = var.postgres_user
    password = var.postgres_password
  }
}
