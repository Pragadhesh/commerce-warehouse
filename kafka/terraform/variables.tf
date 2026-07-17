variable "kafka_bootstrap_servers" {
  description = "Bootstrap server for the kafka service in docker-compose.yml (host port 9094 -- 9092 is reserved for DataHub's own broker)."
  type        = string
  default     = "localhost:9094"
}

variable "topic_name" {
  type    = string
  default = "order-events"
}
