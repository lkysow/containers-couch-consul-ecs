terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.63.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "this" {}

data "aws_security_group" "vpc_default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

resource "aws_ecs_service" "greeter" {
  name            = "${var.name}-greeter"
  cluster         = aws_ecs_cluster.this.arn
  task_definition = module.greeter.task_definition_arn
  desired_count   = 1
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type    = "FARGATE"
  propagate_tags = "TASK_DEFINITION"
  load_balancer {
    target_group_arn = aws_lb_target_group.greeter.arn
    container_name   = "greeter"
    container_port   = 9090
  }
  enable_execute_command = true
}

module "greeter" {
  source = "github.com/hashicorp/terraform-aws-ecs-consul//modules/mesh-task"

  consul_ecs_image = "docker.mirror.hashicorp.services/hashicorpdev/consul-ecs:latest"
  family           = "${var.name}-greeter"
  port             = "9090"
  upstreams = [
    {
      destination_name = "greeting"
      local_bind_port  = 7070
    },
    {
      destination_name = "name"
      local_bind_port  = 8080
    }
  ]
  log_configuration = local.greeter_log_config
  container_definitions = [{
    name             = "greeter"
    image            = "ghcr.io/lkysow/greeter:error-logging"
    essential        = true
    logConfiguration = local.greeter_log_config
    environment = [
      {
        name  = "PORT"
        value = "9090"
      },
      {
        name  = "GREETING_URL"
        value = "http://localhost:7070"
      },
      {
        name  = "NAME_URL"
        value = "http://localhost:8080"
      }
    ]
    portMappings = [
      {
        containerPort = 9090
        hostPort      = 9090
        protocol      = "tcp"
      }
    ]
    healthCheck = {
      command  = ["CMD-SHELL", "echo 1"]
      interval = 30
      retries  = 3
      timeout  = 5
    }
    cpu         = 0
    mountPoints = []
    volumesFrom = []
  }]
  retry_join          = [module.dev_consul_server.server_dns]
  consul_service_name = "greeter"
}

resource "aws_ecs_service" "greeting" {
  name            = "${var.name}-greeting"
  cluster         = aws_ecs_cluster.this.arn
  task_definition = module.greeting.task_definition_arn
  desired_count   = 1
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type            = "FARGATE"
  propagate_tags         = "TASK_DEFINITION"
  enable_execute_command = true
}

module "greeting" {
  source = "github.com/hashicorp/terraform-aws-ecs-consul//modules/mesh-task"

  consul_ecs_image  = "docker.mirror.hashicorp.services/hashicorpdev/consul-ecs:latest"
  family            = "${var.name}-greeting"
  port              = "9090"
  log_configuration = local.greeting_log_config
  container_definitions = [{
    name             = "greeting"
    image            = "ghcr.io/lkysow/greeting"
    essential        = true
    logConfiguration = local.greeting_log_config
    environment = [
      {
        name  = "PORT"
        value = "9090"
      }
    ]
    healthCheck = {
      command  = ["CMD-SHELL", "echo 1"]
      interval = 30
      retries  = 3
      timeout  = 5
    }
  }]
  retry_join          = [module.dev_consul_server.server_dns]
  consul_service_name = "greeting"
  consul_service_meta = {
    group = "blue"
  }
}

resource "aws_ecs_service" "greeting_german" {
  name            = "${var.name}-greeting-german"
  cluster         = aws_ecs_cluster.this.arn
  task_definition = module.greeting_german.task_definition_arn
  desired_count   = 1
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type            = "FARGATE"
  propagate_tags         = "TASK_DEFINITION"
  enable_execute_command = true
}

module "greeting_german" {
  source = "github.com/hashicorp/terraform-aws-ecs-consul//modules/mesh-task"

  consul_ecs_image  = "docker.mirror.hashicorp.services/hashicorpdev/consul-ecs:latest"
  family            = "${var.name}-greeting-german"
  port              = "9090"
  log_configuration = local.greeting_german_log_config
  container_definitions = [{
    name             = "greeting"
    image            = "ghcr.io/lkysow/greeting:german"
    essential        = true
    logConfiguration = local.greeting_german_log_config
    environment = [
      {
        name  = "PORT"
        value = "9090"
      }
    ]
    healthCheck = {
      command  = ["CMD-SHELL", "echo 1"]
      interval = 30
      retries  = 3
      timeout  = 5
    }
  }]
  retry_join          = [module.dev_consul_server.server_dns]
  consul_service_name = "greeting"
  consul_service_meta = {
    group = "green"
  }
}

resource "aws_ecs_service" "name" {
  name            = "${var.name}-name"
  cluster         = aws_ecs_cluster.this.arn
  task_definition = module.name.task_definition_arn
  desired_count   = 1
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type            = "FARGATE"
  propagate_tags         = "TASK_DEFINITION"
  enable_execute_command = true
}

module "name" {
  source = "github.com/hashicorp/terraform-aws-ecs-consul//modules/mesh-task"

  consul_ecs_image  = "docker.mirror.hashicorp.services/hashicorpdev/consul-ecs:latest"
  family            = "${var.name}-name"
  port              = "9090"
  log_configuration = local.name_log_config
  container_definitions = [{
    name             = "name"
    image            = "ghcr.io/lkysow/name"
    essential        = true
    logConfiguration = local.name_log_config
    environment = [
      {
        name  = "PORT"
        value = "9090"
      }
    ]
    healthCheck = {
      command  = ["CMD-SHELL", "echo 1"]
      interval = 30
      retries  = 3
      timeout  = 5
    }
  }]
  retry_join          = [module.dev_consul_server.server_dns]
  consul_service_name = "name"
}

resource "aws_lb" "greeter" {
  name               = "${var.name}-greeter"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.greeter_alb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_security_group" "greeter_alb" {
  name   = "${var.name}-greeter-alb"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Access to example client application."
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.lb_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ingress_from_client_alb_to_ecs" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.greeter_alb.id
  security_group_id        = data.aws_security_group.vpc_default.id
}

resource "aws_security_group_rule" "ingress_from_server_alb_to_ecs" {
  type                     = "ingress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  source_security_group_id = module.dev_consul_server.lb_security_group_id
  security_group_id        = data.aws_security_group.vpc_default.id
}

resource "aws_lb_target_group" "greeter" {
  name                 = "${var.name}-greeter"
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

resource "aws_lb_listener" "greeter" {
  load_balancer_arn = aws_lb.greeter.arn
  port              = "9090"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.greeter.arn
  }
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = var.name
}


locals {
  greeting_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "greeting"
    }
  }

  greeting_german_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "greeting-german"
    }
  }

  greeter_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "greeter"
    }
  }

  name_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "name"
    }
  }
}
