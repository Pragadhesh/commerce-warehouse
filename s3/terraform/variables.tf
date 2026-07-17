variable "minio_endpoint" {
  description = "MinIO's S3 API endpoint (raw-landing service in docker-compose.yml)."
  type        = string
  default     = "http://localhost:9000"
}

variable "minio_access_key" {
  type    = string
  default = "minioadmin"
}

variable "minio_secret_key" {
  type      = string
  default   = "minioadmin"
  sensitive = true
}

variable "bucket_name" {
  description = "Landing bucket for the fiction-retail extract, matching s3/datahub_ingest.yaml."
  type        = string
  default     = "commerce-raw-landing"
}

variable "seed_data_path" {
  description = "Local path to the seed CSVs uploaded as the landing zone's contents."
  type        = string
  default     = "../../postgres/init/data"
}
