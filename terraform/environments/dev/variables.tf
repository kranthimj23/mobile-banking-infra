variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}
