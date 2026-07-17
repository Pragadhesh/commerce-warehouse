resource "kafka_topic" "order_events" {
  name               = var.topic_name
  partitions         = 1
  replication_factor = 1

  config = {
    "retention.ms"   = "604800000"
    "cleanup.policy" = "delete"
  }
}
