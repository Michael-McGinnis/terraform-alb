# Two “return values” printed after a successful terraform apply:
# alb_dns_name        – Canonical DNS endpoint for the ALB
# duckdns_cname_hint  – Pre-formatted string to drop into DuckDNS

output "alb_dns_name" {
  # Human-readable description shows up in `terraform output`
  description = "Public DNS name of the Application Load Balancer"

  # Direct attribute from the aws_lb resource
  value = aws_lb.alb.dns_name
}

output "duckdns_cname_hint" {
  description = "Copy into DuckDNS as a CNAME record"

  # Interpolate the ALB DNS into the exact CNAME string the user needs
  value = "mydemo.duckdns.org → ${aws_lb.alb.dns_name}"
}