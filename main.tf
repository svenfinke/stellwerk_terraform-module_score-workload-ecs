# locals is defined in iam.tf

# ---------------------------------------------------------------------------
# Container definition helpers
# ---------------------------------------------------------------------------

locals {
  # Ordered list of container names (stable within a plan).
  container_names = keys(var.containers)

  # Name of the primary container — first in iteration order.
  primary_container_name = local.container_names[0]

  # Fargate requires CPU/memory to be set at the task level.
  # Derive from the primary container's resource limits; fall back to arm64-compatible defaults.
  # arm64 on Fargate supports: 256 cpu (512/1024/2048 MiB), 512 cpu (1024-4096 MiB), 1024 cpu (2048-8192 MiB), 2048 cpu (4096-16384 MiB), 4096 cpu (8192-30720 MiB)
  task_cpu    = try(var.containers[local.primary_container_name].resources.limits.cpu, "256")
  task_memory = try(var.containers[local.primary_container_name].resources.limits.memory, "512")

  # arm64-compatible CPU/memory pairs for Fargate
  valid_cpu_memory_pairs = {
    "256"  = [512, 1024, 2048]
    "512"  = [1024, 2048, 3072, 4096]
    "1024" = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
    "2048" = [4096, 5120, 6144, 7168, 8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384]
    "4096" = [8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384, 17408, 18432, 19456, 20480, 21504, 22528, 23552, 24576, 25600, 26624, 27648, 28672, 29696, 30720]
  }

  # Validate CPU/memory combination
  valid_memory_list = lookup(local.valid_cpu_memory_pairs, local.task_cpu, [])
  cpu_memory_valid  = contains(local.valid_memory_list, tonumber(local.task_memory))

  # Extract spring_profiles_active from metadata; default to "default"
  spring_profiles_active = try(var.metadata.spring_profiles_active, "default")

  # Build the list of container definition objects consumed by aws_ecs_task_definition.
  container_definitions = [
    for name, c in var.containers : {
      name      = name
      image     = c.image
      essential = name == local.primary_container_name

      # Score command → ECS entryPoint; Score args → ECS command.
      entryPoint = length(c.command) > 0 ? c.command : null
      command    = length(c.args) > 0 ? c.args : null

      # Convert env map to the ECS name/value list format.
      # Inject SPRING_PROFILES_ACTIVE into primary container.
      environment = concat(
        [for k, v in c.env : { name = k, value = v }],
        name == local.primary_container_name ? [
          { name = "SPRING_PROFILES_ACTIVE", value = local.spring_profiles_active }
        ] : []
      )

      # Expose service_port on the primary container; other containers keep their own ports.
      portMappings = name == local.primary_container_name ? [
        {
          containerPort = var.service_port
          protocol      = "tcp"
        }
        ] : [
        for _, p in c.ports : {
          containerPort = p.port
          protocol      = lower(p.protocol)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = name
        }
      }
    }
  ]
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# CloudWatch Log Group
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.app_id}/${var.env_id}/${var.res_id}"
  retention_in_days = 30

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS Cluster
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = local.name_prefix

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Security Group — ALB
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "ALB for ${local.name_prefix}"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "Allow inbound HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Allow outbound to ECS tasks on service port"
    from_port       = var.service_port
    to_port         = var.service_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# ---------------------------------------------------------------------------
# Security Group — ECS tasks
# ---------------------------------------------------------------------------

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs"
  description = "ECS tasks for ${local.name_prefix}"
  vpc_id      = data.aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.service_port
  to_port                      = var.service_port
  ip_protocol                  = "tcp"
  description                  = "Allow inbound traffic on service port from ALB"
}

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = local.name_prefix
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ALB Target Group
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "main" {
  name        = local.name_prefix
  port        = var.service_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200-399"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# ALB Listener Rule — catch-all forward to target group
# ---------------------------------------------------------------------------

resource "aws_lb_listener_rule" "main" {
  listener_arn = aws_lb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS Task Definition
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "main" {
  family                   = local.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.task_cpu
  memory                   = local.task_memory

  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode(local.container_definitions)

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = local.cpu_memory_valid
      error_message = "CPU/memory combination not valid for arm64 Fargate. CPU: ${local.task_cpu}, Memory: ${local.task_memory}. Valid memory values for CPU ${local.task_cpu}: ${join(", ", local.valid_memory_list)}"
    }
  }
}

# ---------------------------------------------------------------------------
# ECS Service
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "main" {
  name            = local.name_prefix
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = local.primary_container_name
    container_port   = var.service_port
  }

  deployment_controller {
    type = "ECS"
  }

  # Allow Terraform to update the task definition without recreating the service.
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = local.common_tags

  depends_on = [aws_lb_listener_rule.main]
}
