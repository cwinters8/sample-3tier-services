locals {
  web_tags  = merge(data.aws_default_tags.app.tags, var.web_tags)
  web_image = "${data.aws_ecr_repository.web.repository_url}:${var.web_image_tag}"
}

data "aws_subnets" "web" {
  tags = local.web_tags
}

data "aws_security_groups" "web" {
  tags = local.web_tags
}

data "aws_ecr_repository" "web" {
  name = var.web_tags.Name
}

resource "aws_ecs_service" "web" {
  name                               = var.web_tags.Name
  cluster                            = data.aws_ecs_cluster.app.arn
  task_definition                    = aws_ecs_task_definition.web.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 300
  enable_ecs_managed_tags            = true
  enable_execute_command             = true
  launch_type                        = "FARGATE"
  propagate_tags                     = "SERVICE"

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = var.web_service_name
    container_port   = var.web_port
  }

  network_configuration {
    subnets         = data.aws_subnets.web.ids
    security_groups = data.aws_security_groups.web.ids
  }

  service_connect_configuration {
    enabled   = true
    namespace = data.aws_ecs_cluster.app.service_connect_defaults[0].namespace

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = var.app_name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-create-group"  = true
        "awslogs-stream-prefix" = "web/service-connect"
        "mode"                  = "non-blocking"
        "max-buffer-size"       = "16m"
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.web_tags

  depends_on = [aws_lb.web]
}

resource "aws_ecs_task_definition" "web" {
  family                   = var.web_tags.Name
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.app_exec.arn
  task_role_arn            = aws_iam_role.app_task.arn
  container_definitions = jsonencode([{
    name  = var.web_service_name
    image = local.web_image
    portMappings = [{
      name          = var.web_service_name
      containerPort = "${var.web_port}"
      appProtocol   = "http"
    }]
    environment = [
      {
        name  = "API_HOST",
        value = "https://${aws_route53_record.api.fqdn}"
      },
      {
        name  = "PORT",
        value = tostring(var.web_port)
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "${var.app_name}"
        awslogs-region        = data.aws_region.current.name
        awslogs-create-group  = "true"
        awslogs-stream-prefix = var.web_service_name
        mode                  = "non-blocking"
        max-buffer-size       = "16m"
      }
    }
  }])

  tags = var.web_tags

  depends_on = [
    aws_iam_role_policy_attachment.app_exec,
    aws_iam_role_policy_attachment.task_ecs_exec,
    aws_iam_role_policy_attachment.task_logs
  ]
}

resource "aws_appautoscaling_target" "web" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${local.ecs_cluster_name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.web_tags
}

resource "aws_appautoscaling_policy" "web" {
  name               = "${var.web_tags.Name}-task-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 30
    scale_out_cooldown = 30

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_lb" "web" {
  name                       = var.web_tags.Name
  load_balancer_type         = "application"
  security_groups            = data.aws_security_groups.public.ids
  subnets                    = data.aws_subnets.public.ids
  drop_invalid_header_fields = true
  internal                   = false

  access_logs {
    enabled = true
    bucket  = aws_s3_bucket.app_logs.id
    prefix  = "web/lb/access"
  }

  tags = var.web_tags

  depends_on = [aws_s3_bucket_policy.lb_logging]
}

resource "aws_lb_target_group" "web" {
  name        = var.web_tags.Name
  port        = 80
  target_type = "ip"
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.app.id

  tags = var.web_tags
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.domain.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = var.web_tags
}

resource "aws_route53_record" "web" {
  zone_id         = data.aws_route53_zone.domain.zone_id
  type            = "A"
  name            = var.domain
  allow_overwrite = true

  alias {
    zone_id                = aws_lb.web.zone_id
    name                   = aws_lb.web.dns_name
    evaluate_target_health = true
  }
}

output "web_endpoint" {
  value = "https://${aws_route53_record.web.fqdn}"
}

output "web_image" {
  value = local.web_image
}
