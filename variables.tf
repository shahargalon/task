# S3 Bucket Configuration
variable "bucket_name" {
  description = "The name of the S3 bucket."
  type        = string
}

# EC2 Instance Configuration
variable "instance_name" {
  description = "The name of the EC2 instance."
  type        = string
}

variable "instance_type" {
  description = "The type of the EC2 instance."
  type        = string
  default     = "t2.micro" # You can change the default if needed
}

variable "vpc_id" {
  description = "The ID of the VPC in which the EC2 instance will be launched."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet in which the EC2 instance will be launched."
  type        = string
}

variable "s3_endpointID" {
  description = "the ID of the s3 endpoint"
  type        = string
}

# Optional: If you're using an SSH key pair to access the EC2 instance, you can add this variable
variable "key_name" {
  description = "The name of the SSH key pair to use for EC2 instance."
  type        = string
  default     = "" # Leave blank if not using SSH keys
}

# alb configuration
variable "alb_name" {
  description = "The name of the ALB."
  type        = string
}

variable "alb_subnets" {
  description = "The ID of the subnets in which the EC2 instance will be launched."
  type        = list(string)
}