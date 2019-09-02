variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "ap-southeast-2"
}

variable "az_count" {
  default     = 3
  description = "Available zone in region"
}
variable "instance_type" {
  default     = "t2.micro"
  description = "AWS instance type"
}
