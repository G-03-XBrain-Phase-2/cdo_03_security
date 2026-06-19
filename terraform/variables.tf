variable "aws_region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS Region to deploy resources"
}

variable "email_address" {
  type        = string
  description = "Email address to receive SNS alert notifications"
}
