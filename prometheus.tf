resource "aws_ecs_service" "prometheus" {
  name            = "${var.name}-prometheus"
  cluster         = aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type            = "FARGATE"
  propagate_tags         = "TASK_DEFINITION"
  enable_execute_command = true
  service_registries {
    registry_arn   = aws_service_discovery_service.prometheus.arn
    container_name = "prometheus"
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.name}-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  container_definitions = jsonencode([
    {
      name             = "prometheus"
      image            = "ghcr.io/lkysow/prometheus:v2.31.1"
      essential        = true
      user             = "root"
      logConfiguration = local.prometheus_log_config
      entryPoint       = ["/bin/sh", "-ec"]
      command          = [local.prometheus_command]
      environment = [
      ]
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]
      cpu         = 0
      mountPoints = []
      volumesFrom = []
    }
  ])
}

resource "aws_iam_role" "task" {
  name = "${var.name}-prometheus-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name   = "exec"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
  }
}

resource "aws_iam_policy" "execution" {
  name        = "${var.name}-prometheus-execution"
  path        = "/ecs/"
  description = "${var.name} prometheus execution policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "execution" {
  name = "${var.name}-prometheus-execution"
  path = "/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.id
  policy_arn = aws_iam_policy.execution.arn
}

locals {
  prometheus_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "prometheus"
    }
  }
  prometheus_command = <<EOT

cat > prometheus.yml << EOF
global:
  evaluation_interval: 1m
  scrape_interval: 15s
  scrape_timeout: 10s
scrape_configs:
- job_name: prometheus
  static_configs:
  - targets:
    - localhost:9090
- job_name: consul
  metrics_path: /metrics
  consul_sd_configs:
  - server: '${module.dev_consul_server.server_dns}:8500'
  relabel_configs:
  - source_labels:
    - __meta_consul_tagged_address_lan
    regex: '(.*)'
    replacement: '\$${1}:20200'
    target_label: '__address__'
    action: 'replace'

EOF
mkdir /data

exec /bin/prometheus \
        --storage.tsdb.retention.time=15d \
        --storage.tsdb.path=/data \
        --web.console.libraries=/etc/prometheus/console_libraries \
        --web.console.templates=/etc/prometheus/consoles \
        --web.enable-lifecycle
EOT
}

resource "aws_service_discovery_private_dns_namespace" "prometheus" {
  name        = "prometheus"
  description = "The namespace for prometheus."
  vpc         = module.vpc.vpc_id
}

resource "aws_service_discovery_service" "prometheus" {
  name = var.name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.prometheus.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_lb_target_group" "prometheus" {
  name                 = var.name
  port                 = 9090
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "ip"
  deregistration_delay = 10
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
  }
}

resource "aws_lb" "prometheus" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prometheus.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = aws_lb.prometheus.arn
  port              = "9090"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}

resource "aws_security_group" "prometheus" {
  name   = var.name
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "Access to Prometheus."
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    cidr_blocks     = var.lb_ingress_cidrs
    security_groups = []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ingress_from_prometheus_alb_to_ecs" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.prometheus.id
  security_group_id        = module.vpc.default_security_group_id
}
