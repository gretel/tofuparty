resource "aws_efs_file_system" "this" {
  creation_token = local.name
  encrypted      = true

  tags = local.tags
}

resource "aws_efs_mount_target" "this" {
  count           = var.az_count
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs"
  description = "NFS access from Fargate tasks"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "NFS from Fargate"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate.id]
  }
}

resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/data"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }
}

# Tailscale node state lives here (separate from served files, so the
# node key is never visible in the copyparty web UI)
resource "aws_efs_access_point" "tailscale" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/tsstate"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "700"
    }
  }
}
