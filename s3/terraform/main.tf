resource "aws_s3_bucket" "raw_landing" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "raw_landing" {
  bucket = aws_s3_bucket.raw_landing.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "seed_files" {
  for_each = fileset(var.seed_data_path, "*.csv")

  bucket = aws_s3_bucket.raw_landing.id
  key    = "fiction_retail/${trimsuffix(each.value, ".csv")}/${each.value}"
  source = "${var.seed_data_path}/${each.value}"
  etag   = filemd5("${var.seed_data_path}/${each.value}")
}
