variable "name" {
  description = "Name to be used on all the resources as identifier."
  type        = string
  default     = "consul-ecs"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "lb_ingress_cidrs" {
  description = "CIDRs to use in the load balancer security groups to ensure only you can access the Consul UI and example application."
  type        = list(string)
}
