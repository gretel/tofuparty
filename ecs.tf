resource "aws_ecs_cluster" "this" {
  name = local.name
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_iam_role" "execution" {
  name = "${local.name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Lets ECS fetch the Tailscale auth key from Parameter Store at task start
resource "aws_iam_role_policy" "execution_ssm" {
  name = "ssm-get-tailscale-auth"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters"]
      Resource = [aws_ssm_parameter.tailscale_auth.arn]
    }]
  })
}

resource "aws_iam_role" "task" {
  name = "${local.name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "task_efs" {
  name = "efs-mount"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite",
      ]
      Resource = [
        aws_efs_file_system.this.arn,
        aws_efs_access_point.this.arn,
        aws_efs_access_point.tailscale.arn,
      ]
    }]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name = "copyparty"
      # Docker Hub: copyparty/ac:latest
      # GHCR mirror (no auth needed for pulls): ghcr.io/9001/copyparty-ac:latest
      image     = var.container_image
      user      = "1000"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      # ── Copyparty arguments ────────────────────────────────────────
      # -v /w::rw,admin   — serve /w as webroot, read-write for admin
      # -a admin:<pw>     — account admin with your chosen password
      # -e2ds -e2ts       — filesystem + media-tag indexing
      # --no-robots       — don't get crawled
      # --no-logues       — disable prologue/epilogue html for safety
      # --no-dav          — disable WebDAV (reduces attack surface)
      # --vague-403       — return 404 instead of 401
      # --nih             — hide server hostname from listings
      # --qrs             — print HTTPS QR code (goes to CloudWatch log)
      # --z-off 127.0.0.0/8 — restrict zeroconf to loopback = disabled
      # --forget-ip 43200 — forget uploader IPs after 12h (GDPR)
      # -lo ...           — write compressed daily logs to EFS
      #
      # CloudFront is a reverse proxy, so copyparty must read the real
      # client IP from X-Forwarded-For. With CloudFront → ALB the header
      # contains "<viewer-ip>, <cf-edge-ip>" so -2 picks the viewer.
      command = [
        "-v", "/w::rwmd,admin:rw,consumer:c,unp_who=3",
        "-v", "/w/.logs:.logs:rwmd,admin",
        "-a", "admin:${random_password.admin.result}",
        "-a", "consumer:${random_password.consumer.result}",
        "-e2ds", "-e2ts",
        "--no-robots",
        "--no-logues",
        "--no-readme",
        "--no-dav",
        "--bup-ck", "no",
        "--put-ck", "no",
        "--vague-403",
        "-nih",
        "--qrs",
        "--z-off", "127.0.0.0/8",
        "--shr", "/share",
        "--shr-db", "/w/.logs/shares.db",
        "--site", "https://${aws_cloudfront_distribution.this.domain_name}/",
        "--forget-ip", "43200",
        "--unpost", "315360000", # consumer can unpost own uploads at any time (10y)
        "-lo", "/w/.logs/cpp-%Y-%m-%d.txt.xz",
        "--xff-hdr", "X-Forwarded-For",
        "--xff-src", var.vpc_cidr,
        "--rproxy", "-2",
        "--acao", "https://${aws_cloudfront_distribution.this.domain_name}",
      ]

      environment = [
        { name = "PRTY_NO_DB_LOCK", value = "1" },
        { name = "PRTY_FFMPEG_BIN", value = "/usr/bin/ffmpeg" },
        { name = "PRTY_FFPROBE_BIN", value = "/usr/bin/ffprobe" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "copyparty"
        }
      }

      linuxParameters = {
        initProcessEnabled = true
      }

      mountPoints = [
        {
          sourceVolume  = "data"
          containerPath = "/w"
          readOnly      = false
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:${var.container_port}/ >/dev/null 2>&1 || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = "tailscale"
      image     = "tailscale/tailscale:latest"
      essential = false # copyparty keeps running if the sidecar fails

      environment = [
        # Fargate has no /dev/net/tun, so run in userspace mode
        { name = "TS_USERSPACE", value = "true" },
        # Stable node name in the tailnet
        { name = "TS_HOSTNAME", value = local.name },
        # Persist node identity + key on EFS (non-ephemeral node)
        { name = "TS_STATE_DIR", value = "/var/lib/tailscale" },
        # Subnet router for the VPC + built-in Tailscale SSH
        { name = "TS_EXTRA_ARGS", value = "--advertise-routes=${var.vpc_cidr} --ssh" },
      ]

      secrets = [
        { name = "TS_AUTHKEY", valueFrom = aws_ssm_parameter.tailscale_auth.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "tailscale"
        }
      }

      mountPoints = [
        {
          sourceVolume  = "tsstate"
          containerPath = "/var/lib/tailscale"
          readOnly      = false
        }
      ]
    },
  ])

  volume {
    name = "data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.this.id
        iam             = "ENABLED"
      }
    }
  }

  volume {
    name = "tsstate"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.tailscale.id
        iam             = "ENABLED"
      }
    }
  }

  depends_on = [aws_efs_access_point.this, aws_efs_access_point.tailscale]
}

resource "aws_security_group" "fargate" {
  name        = "${local.name}-fargate"
  description = "Allow traffic from ALB to Fargate"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "this" {
  name            = local.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.fargate.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "copyparty"
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  wait_for_steady_state = true

  depends_on = [
    aws_lb_target_group.this,
    aws_lb.this,
  ]
}
