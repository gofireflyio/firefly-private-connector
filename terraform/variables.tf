variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-12345678"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

variable "security_group_id" {
  description = "ID of the security group"
  type        = string
}

variable "user" {
  description = "SSH user"
  type        = string
}

variable "remote_host" {
  description = "Remote host"
  type        = string
}

variable "remote_port" {
  description = "Remote port"
  type        = number
  default     = 22
}

variable "source_port" {
  description = "Source port"
  type        = number
}

variable "target_host" {
  description = "Target host"
  type        = string
}

variable "target_port" {
  description = "Target port"
  type        = number
}

variable "certificate_path" {
  description = "AWS Secrets Manager path for the certificate secret"
  type        = string
}

variable "certificate_pem" {
  description = "Certificate PEM"
  type        = string
}

variable "sleep_duration" {
  description = "Duration to sleep before retrying in seconds"
  type        = number
  default     = 5
}

variable "app_version" {
  description = "Firefly relay application version"
  type        = string
  default     = "1.0.0"
}

variable "module_version" {
  description = "Firefly relay module version"
  type        = string
  default     = "0.1.0"
}

variable "tags" {
    description = "Tags to apply to resources"
    type        = map(string)
    default     = {}
}