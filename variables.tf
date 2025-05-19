variable "region" {
  description = "AWS region to launch resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  type        = string
}

variable "key_name" {
  description = "Key pair name for EC2 SSH access"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to create or use"
  type        = string
}

