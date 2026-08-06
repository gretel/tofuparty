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

## Teardown

```
tofu destroy
```

`tofu destroy` removes the whole stack including the EFS filesystem and its data.
