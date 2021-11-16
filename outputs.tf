output "consul_server_lb_address" {
  value = "http://${module.dev_consul_server.lb_dns_name}:8500"
}

output "mesh_client_lb_address" {
  value = "http://${aws_lb.greeter.dns_name}:9090"
}
