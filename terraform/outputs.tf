output "s3_bucket_name" {
  value       = aws_s3_bucket.macie_bucket.id
  description = "Name of the created S3 bucket"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.macie_alerts.arn
  description = "ARN of the SNS topic"
}

output "macie_job_id" {
  value       = aws_macie2_classification_job.macie_job.id
  description = "ID of the Macie Classification Job"
}

output "instruction" {
  value = "IMPORTANT: 1. Check your email inbox and click 'Confirm Subscription' to enable SNS alerts. 2. Wait 3-5 minutes for the Macie job to complete. 3. Check Macie Console for findings and check email for the JSON notification."
}
