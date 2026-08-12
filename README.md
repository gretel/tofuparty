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
| `tailscale_auth_key` | — | Tailscale auth key for the sidecar node (required, no default) |

Set via `TF_VAR_<name>` or `-var` flag.

## Private access (Tailscale)

The ECS task runs a `tailscale` sidecar that joins your tailnet, so the whole
VPC is reachable from your devices without exposing anything publicly:

- **Subnet router** — the sidecar advertises `10.0.0.0/16` (the VPC CIDR).
  Approve the route in the Tailscale admin console
  (Machines → your node → … → Edit route settings), then any tailnet device
  can reach the ECS task/ALB by their private IPs.
- **Tailscale SSH** — `--ssh` enables Tailscale's built-in SSH server on the
  node, so you get a shell inside the sidecar container:

  ```
  ssh root@copyparty-demo
  ```

  The sidecar shares the task's network namespace with copyparty, so from
  that shell you can poke the app directly, e.g. `wget -qO- localhost:3923`.

Notes:

- Fargate has no `/dev/net/tun`, so the sidecar runs Tailscale in userspace
  networking mode (`TS_USERSPACE=true`) — no privileged containers needed.
- The node is non-ephemeral: its state (including the node key) persists on
  EFS under a dedicated access point (`/tsstate`), separate from served files.
- The auth key is passed via Parameter Store (`/copyparty-demo/tailscale-auth-key`)
  as an ECS secret, never as a plaintext env var.
- The sidecar is non-essential: if Tailscale dies, copyparty keeps running.

To create an auth key: https://login.tailscale.com/admin/settings/keys

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
| `secrets.tf` | Auto-generated passwords, Tailscale auth key (SSM) |
| `provider.tf` | AWS provider config |
| `vpc.tf` | VPC, subnets, gateways, routing |
| `efs.tf` | EFS filesystem, mount targets, access points (data + tailscale state) |
| `ecs.tf` | ECS cluster, IAM roles, task definition, service |
| `alb.tf` | ALB, target group, listener |
| `cloudfront.tf` | CloudFront distribution |
| `outputs.tf` | Outputs |

## Teardown

```
tofu destroy
```

`tofu destroy` removes the whole stack including the EFS filesystem and its data.
