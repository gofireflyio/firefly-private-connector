module "ec2_instance" {
  source = "./modules/ec2_instance"

  instance_type = var.instance_type
  key_name      = var.key_name
  tags          = var.tags
}