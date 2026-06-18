variable "aws_region"   { type = string; default = "us-east-1" }
variable "environment"  {
  type = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Must be staging or production."
  }
}
