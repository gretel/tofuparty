# tofuparty — copyparty on aws via opentofu

## Components

Browser → CloudFront (TLS) → ALB (HTTP) → ECS Fargate (copyparty/ac) → EFS 🥳

## Prerequisites

- OpenTofu ≥ 1.6
- AWS credentials

## Usage

```
tofu init
tofu apply
tofu output admin_login
tofu output consumer_login
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | eu-central-1 | AWS region |
| `name_prefix` | copyparty-demo | Prefix for all resource names |
| `vpc_cidr` | 10.0.0.0/16 | VPC CIDR block |
| `az_count` | 2 | Number of availability zones |
| `container_cpu` | 512 | ECS task CPU units |
| `container_memory` | 1024 | ECS task memory (MiB) |
| `container_image` | copyparty/ac:latest | Container image |
| `container_port` | 3923 | Container HTTP port |
| `log_retention_days` | 7 | CloudWatch log retention |
| `password_length` | 24 | Length of auto-generated passwords |
| `health_check_grace_period` | 60 | ECS health check grace period (s) |

Set via `TF_VAR_<name>` or `-var` flag.

## Accounts

| Volume | Access | Account |
|--------|--------|---------|
| `/w` | read/write/move/delete | admin |
| `/w` | read/write + delete own uploads | consumer |
| `/w/.logs` | server logs, admin only (hidden volume) | admin |

Passwords auto-generated via `random_password`. Consumer can only delete files it uploaded itself (copyparty `unpost`, 10-year window); admin can delete anything at any time. Server logs are written to `/w/.logs` and reachable only via the dedicated admin-only volume mount. Add accounts by editing the `command` list in `ecs.tf`.

## Files

| File | Contents |
|------|----------|
| `versions.tf` | Provider constraints |
| `data.tf` | Data sources (caller identity, region, partition) |
| `variables.tf` | Input variables with defaults |
| `locals.tf` | Derived locals (name, tags) |
| `secrets.tf` | Auto-generated passwords |
| `provider.tf` | AWS provider config |
| `vpc.tf` | VPC, subnets, gateways, routing |
| `efs.tf` | EFS filesystem, mount targets, access point |
| `ecs.tf` | ECS cluster, IAM roles, task definition, service |
| `alb.tf` | ALB, target group, listener |
| `cloudfront.tf` | CloudFront distribution |
| `outputs.tf` | Outputs |

## Teardown

```
tofu destroy
```

`tofu destroy` removes the whole stack including the EFS filesystem and its data.
