output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "duckdns_cname_hint" {
  description = "Copy this into DuckDNS as a CNAME record"
  value       = "mydemo.duckdns.org → ${module.alb.dns_name}"
}