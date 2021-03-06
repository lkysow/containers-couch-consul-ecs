# Run the Consul dev server as an ECS task.
module "dev_consul_server" {
  source = "github.com/hashicorp/terraform-aws-ecs-consul//modules/dev-server?ref=dev-server-extraconfig"

  consul_image                = "public.ecr.aws/hashicorp/consul:1.10.4"
  name                        = "${var.name}-consul-server"
  ecs_cluster_arn             = aws_ecs_cluster.this.arn
  subnet_ids                  = module.vpc.private_subnets
  vpc_id                      = module.vpc.vpc_id
  lb_enabled                  = true
  lb_subnets                  = module.vpc.public_subnets
  lb_ingress_rule_cidr_blocks = var.lb_ingress_cidrs
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "consul-server"
    }
  }
  launch_type  = "FARGATE"
  extra_config = <<EOT
ui_config {
  enabled = true
  metrics_provider = "prometheus"
  metrics_proxy {
    base_url = "http://${aws_service_discovery_service.prometheus.name}.${aws_service_discovery_private_dns_namespace.prometheus.name}:9090"
  }
}
EOT
}
