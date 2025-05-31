output "alb_dns_name" {
    value = module.alb.lb_dns_name
}

output "duckdns_cname_hint" {
    value = "mydemo.duckdns.org → ${module.alb.lb_dns_name}"
}