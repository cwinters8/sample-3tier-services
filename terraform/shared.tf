locals {
  public_tags      = merge(data.aws_default_tags.app.tags, var.public_tags)
  ecs_cluster_name = "${var.app_name}-cluster"
}

data "aws_default_tags" "app" {}

data "aws_vpc" "app" {
  tags = data.aws_default_tags.app.tags
}

data "aws_ecs_cluster" "app" {
  cluster_name = local.ecs_cluster_name
}

data "aws_subnets" "public" {
  tags = local.public_tags
}

data "aws_security_groups" "public" {
  tags = local.public_tags
}

data "aws_route53_zone" "domain" {
  name = var.domain
}

data "aws_acm_certificate" "domain" {
  domain = var.domain

  tags = local.public_tags
}
