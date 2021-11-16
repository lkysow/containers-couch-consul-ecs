output "consul_server_lb_address" {
  value = "http://${module.dev_consul_server.lb_dns_name}:8500"
}

output "greeter_lb_address" {
  value = "http://${aws_lb.greeter.dns_name}:9090"
}

output "prometheus_lb_address" {
  value = "http://${aws_lb.prometheus.dns_name}:9090"
}
