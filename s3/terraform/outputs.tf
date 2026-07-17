output "bucket_name" {
  value = aws_s3_bucket.raw_landing.bucket
}

output "seed_object_count" {
  value = length(aws_s3_object.seed_files)
}
