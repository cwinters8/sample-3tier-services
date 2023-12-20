locals {
  api_tags  = merge(data.aws_default_tags.app.tags, var.api_tags)
  api_image = "${data.aws_ecr_repository.api.repository_url}:${var.api_image_tag}"
}

data "aws_subnets" "api" {
  tags = local.api_tags
}

data "aws_security_groups" "api" {
  tags = local.api_tags
}

data "aws_rds_cluster" "db" {
  cluster_identifier = var.db_name
}

data "aws_secretsmanager_secret" "app_db_pw" {
  name = "${var.app_name}-db-pw"
}

data "aws_ecr_repository" "api" {
  name = var.api_tags.Name
}

resource "aws_ecs_service" "api" {
  name                               = var.api_tags.Name
  cluster                            = data.aws_ecs_cluster.app.arn
  task_definition                    = aws_ecs_task_definition.api.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 300
  enable_ecs_managed_tags            = true
  enable_execute_command             = true
  launch_type                        = "FARGATE"
  propagate_tags                     = "SERVICE"

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = var.api_service_name
    container_port   = var.api_port
  }

  network_configuration {
    subnets         = data.aws_subnets.api.ids
    security_groups = data.aws_security_groups.api.ids
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
        "awslogs-stream-prefix" = "api/service-connect"
        "mode"                  = "non-blocking"
        "max-buffer-size"       = "16m"
      }
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.api_tags
}

resource "aws_ecs_task_definition" "api" {
  family                   = var.api_tags.Name
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.app_exec.arn
  task_role_arn            = aws_iam_role.api_task.arn
  container_definitions = jsonencode([{
    name  = var.api_service_name
    image = local.api_image
    portMappings = [{
      name          = var.api_service_name
      containerPort = var.api_port
      appProtocol   = "http"
    }]
    secrets = [{
      name      = "DB_PASS"
      valueFrom = data.aws_secretsmanager_secret.app_db_pw.arn
    }]
    environment = [{
      name  = "DB_HOST",
      value = data.aws_rds_cluster.db.endpoint
      }, {
      name  = "DB_NAME"
      value = "pg3tier"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "${var.app_name}"
        awslogs-region        = data.aws_region.current.name
        awslogs-create-group  = "true"
        awslogs-stream-prefix = var.api_service_name
        mode                  = "non-blocking"
        max-buffer-size       = "16m"
      }
    }
  }])

  tags = var.api_tags

  depends_on = [
    aws_iam_role_policy_attachment.app_exec,
    aws_iam_role_policy_attachment.api_task_ecs_exec,
    aws_iam_role_policy_attachment.api_task_logs
  ]
}

resource "aws_iam_role" "api_task" {
  name               = "${var.api_tags.Name}-tasks"
  description        = "API ECS Fargate task role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role_policy.json

  tags = var.api_tags
}

resource "aws_iam_role_policy_attachment" "api_task_ecs_exec" {
  role       = aws_iam_role.api_task.name
  policy_arn = aws_iam_policy.task_ecs_exec.arn
}

resource "aws_iam_role_policy_attachment" "api_app_db_pw_secret" {
  role       = aws_iam_role.api_task.name
  policy_arn = data.aws_iam_policy.app_db_pw_secret.arn
}

data "aws_iam_policy" "app_db_pw_secret" {
  name = "${var.app_name}-db-user-secret"
}

resource "aws_appautoscaling_target" "api" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${local.ecs_cluster_name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = var.api_tags
}

resource "aws_appautoscaling_policy" "api" {
  name               = "${var.api_tags.Name}-task-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 30
    scale_out_cooldown = 30

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_lb" "api" {
  name                       = var.api_tags.Name
  load_balancer_type         = "application"
  security_groups            = data.aws_security_groups.public.ids
  subnets                    = data.aws_subnets.public.ids
  drop_invalid_header_fields = true
  internal                   = false

  access_logs {
    enabled = true
    bucket  = aws_s3_bucket.app_logs.id
    prefix  = "api/lb/access"
  }

  tags = var.api_tags

  depends_on = [aws_s3_bucket_policy.lb_logging]
}

resource "aws_lb_target_group" "api" {
  name        = var.api_tags.Name
  port        = 80
  target_type = "ip"
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.app.id

  health_check {
    enabled = true
    path    = var.api_default_url_path
  }

  tags = var.api_tags
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.domain.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  tags = var.api_tags
}

resource "aws_route53_record" "api" {
  zone_id         = data.aws_route53_zone.domain.zone_id
  type            = "A"
  name            = "${var.api_service_name}.${var.domain}"
  allow_overwrite = true

  alias {
    zone_id                = aws_lb.api.zone_id
    name                   = aws_lb.api.dns_name
    evaluate_target_health = true
  }
}

output "api_endpoint" {
  value = "https://${aws_route53_record.api.fqdn}${var.api_default_url_path}"
}

output "api_image" {
  value = local.api_image
}
