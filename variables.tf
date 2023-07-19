variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  default = "my-key-pair"
}

variable "tags" {
  type    = map(string)
  default = {
    Name = "My EC2 Instance"
  }
}