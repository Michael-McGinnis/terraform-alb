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
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "${var.project}-vpc"
  cidr = "10.0.0.0/16"

  # Using slice, pick first AZ based on var.az_count
  azs = slice(data.aws_availability_zones.all.names, 0, var.az_count)
  # One /24 public subnet per AZ
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # DNS hostname is required for the ALB to resolve instance names
  enable_dns_hostnames = true
}

# Find the latest 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  # range() returns numbers 0..az_count-1
  # tostring(i) converts each number to a string, satisfying for_each
  az_indexes = toset([for i in range(var.az_count) : tostring(i)])
}

# ────────────────────────────────────────────────────────────────────────────
# EC2 module (“web” servers); 1 per AZ
# ────────────────────────────────────────────────────────────────────────────
module "web" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.0"

  for_each      = local.az_indexes  # Create N identical modules
  name          = "${var.project}-web-${each.key}"
  ami           = data.aws_ami.al2023.id
  instance_type = "t2.micro"

  # Pin each instance to a different subnet (one per AZ)
  subnet_id = module.vpc.public_subnets[each.key]

  # ─────────────────────────────────────────────────────────────────────────────
  # FIX: Replace default SG with dedicated "web" SG so that ALB health checks 
  #      (port 80) can reach EC2 instances. Previously, instances lived in the 
  #      default VPC SG, which blocked ALB traffic. Now they use aws_security_group.web.
  # ─────────────────────────────────────────────────────────────────────────────
  vpc_security_group_ids = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = "hello-alb"

  # Attach the script
  user_data = file("${path.module}/userdata.sh")

  tags = { Project = var.project }
}

# List of instance IDs
output "web_instance_ids" {
  value = [for m in module.web : m.id]
}

# ────────────────────────────────────────────────────────────────────────────
# Security group for ALB: allows ALB to accept HTTP traffic from the world
# ────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name_prefix = "${var.project}-alb-sg-" # Random suffix
  description = "Allow HTTP in, all out"
  vpc_id      = module.vpc.vpc_id  # SG inside the VPC

  ingress {  # Open port 80 to outside world
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {  # Allow all outbound traffic
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

# ────────────────────────────────────────────────────────────────────────────
# Security Group for Web Instances: allows only ALB SG to reach port 80
# ────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "web" {
  name_prefix = "${var.project}-web-sg-"  # Random suffix, e.g. "hello-alb-web-sg-"
  description = "Allow HTTP (80) only from the ALB SG"
  vpc_id      = module.vpc.vpc_id  # Same VPC as ALB and instances

  ingress {
    description            = "Allow ALB health checks and HTTP traffic"
    from_port              = 80
    to_port                = 80
    protocol               = "tcp"
    security_groups        = [aws_security_group.alb.id]  # Source = ALB SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-web-sg" }
}

# ────────────────
# Load balancer
# ────────────────
resource "aws_lb" "alb" {
  name               = "${var.project}-alb"  # <= 32 chars
  internal           = false  # Internet facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = { Name = "${var.project}-alb" }
}

# ─────────────────────────────────────
# Target group for the web instances
# ─────────────────────────────────────
resource "aws_lb_target_group" "web" {
  name_prefix = "tg-"  # AWS adds random suffix
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"  # EC2 Instance ID
  vpc_id      = module.vpc.vpc_id

  health_check {  # Pings “/” (root of the web server) every 30 seconds; 2 failures = unhealthy
    path                = "/"
    matcher             = "200"
    interval            = 30
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.project}-tg" }
}

# ───────────────────────────────────────────────
# Listener – forwards HTTP to the target group
# ───────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {  # Forward everything to the TG
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ──────────────────────────────────────────────────────────
# Attach every EC2 instance to the target group
# ──────────────────────────────────────────────────────────
resource "aws_lb_target_group_attachment" "web" {
  # module.web is a map created via `for_each` (keys "0", "1", …); keys known at plan time
  for_each = module.web

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = each.value.id  # instance ID
  port             = 80
}
