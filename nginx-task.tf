resource "aws_ecs_task_definition" "nginx" {
  family       = "${local.prefix}-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu          = 512
  memory       = 1024

  execution_role_arn = aws_iam_role.nginx_ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.nginx_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      linuxParameters = {
        initProcessEnabled = true
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nginx_log_group.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "fargate"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "nginx_service" {
  name                   = "${local.prefix}-nginx-service"
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.nginx.arn
  desired_count          = 1
  platform_version       = "LATEST"
  enable_execute_command = true
  propagate_tags         = "SERVICE" #  Propagate tags from the service to the tasks

  network_configuration {
    subnets = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
      aws_subnet.private_3.id,
    ]
    security_groups = [aws_security_group.nginx_task.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 0
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 30

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  tags = {
    Name    = "${local.prefix}-nginx"
    DnsName = aws_route53_record.nginx.fqdn
    HostedZoneId = aws_route53_zone.services.zone_id
  }
}

resource "aws_appautoscaling_target" "nginx_scaling_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.nginx_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "nginx_scaling_policy" {
  name               = "nginx-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.nginx_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.nginx_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.nginx_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 50.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

resource "aws_cloudwatch_log_group" "nginx_log_group" {
  name              = "${local.prefix}-nginx-log-group"
  retention_in_days = 7
}

resource "aws_security_group" "nginx_task" {
  name        = "${local.prefix}-nginx-task"
  description = "Security group for the nginx ECS task"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
}

resource "aws_iam_role" "nginx_task_role" {
  name_prefix = "${local.prefix}-nginx-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "nginx_ecs_task_role_policy" {
  name_prefix = "${local.prefix}-nginx"
  role        = aws_iam_role.nginx_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "ssm:*",
          "ssmmessages:*",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "nginx_ecs_task_execution_role" {
  name_prefix = "${local.prefix}-nginx-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "nginx_ecs_task_execution_policy" {
  name_prefix = "${local.prefix}-nginx-"
  role        = aws_iam_role.nginx_ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:*",
          "ecr:*",
          "kms:*",
          "logs:*",
          "secretsmanager:*",
          "ssm:*",
        ],
        Resource = "*"
      }
    ]
  })
}
