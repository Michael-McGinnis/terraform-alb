# Main file will outline the actual infrastructure i.e. VPC, EC2, ALB, & DNS

/* Core infrastructure:
   1) VPC   – one public subnet per AZ
   2) EC2   – Nginx servers, bootstrapped by userdata.sh
   3) ALB   – Layer-7 load balancer, health checks, listener

 Uses official terraform-aws-modules to avoid boilerplate
 and to show best-practice inputs/outputs.

 Gather all AZ names in the chosen region

 VPC module (public-only, free-tier friendly) */

# Gather all AZ names in the chosen region

data "aws_availability_zones" "all" {}

# VPC Module (Public only & free-tier)
module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "5.5.0"

    name                    = "${var.project}-vpc"
    cidr                    = "10.0.0.0/16"

    # Using slice, pick first AZ based on var.az_count
    azs                     = slice(data.aws_availability_zones.all.names, 0, var.az_count)
    # One /24 public subnet per AZ
    public_subnets          = ["10.0.1.0/24", "10.0.2.0/24"]

    # DNS hostname is required for the ALB to resolve instance names
    enable_dns_hostnames    = true
}

# Find the latest 2023 AMI
data "aws_ami" "al2023" {
  most_recent   = true
  owners        = ["amazon"]
  filter {
    name = "name" 
    values = ["al2023-ami-*-x86_64"]
  }
}

# Convert 0..(az_count-1) into a set of strings for `for_each`
locals {
  az_indexes = toset(range(var.az_count))
}

# EC2 instance; 1 per AZ
module "web" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.0"

  for_each                  = local.az_indexes # Create N identical modules
  name                      = "${var.project}-web-${each.key}"
  ami                       = data.aws_ami.al2023.id
  instance_type             = "t2.micro"

  # Pin each instance to a different subnet (one per AZ)
  subnet_id  = module.vpc.public_subnets[each.key]

  vpc_security_group_ids    = [module.vpc.default_security_group_id]

  # Attach the script
  user_data                 = file("${path.module}/userdata.sh")

  tags                      = {Project = var.project}
}

# List of instance IDs
output "web_instance_ids" {
  value = [for m in module.web : m.id]
}

# ALB module (layer 7)
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.5.0"

  name                  = ":{var.project}-alb"
  load_balancer_type    = "application"
  vpc_id                = module.vpc.vpc_id
  subnets               = module.vpc.public_subnets

# Target group that points to all instances
  target_groups = [{
    name_prefix  = "tg"
    port         = 80
    protocol     = "HTTP"
    target_type  = "instance"
    health_check = {path = "/", matcher = "200"}

    # Map every instance ID into the TG
    targets      = [for id in module.web.imstance_ids: {id = id, port = 80}]
  }]

# One listener on port 80 forwarding to TG at index 1 = TG[0]
  listeners = [{
    port        = 80
    protocol    = "HTTP"
    target_group_index = 0
  }]
}