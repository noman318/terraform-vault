# Terraform + HashiCorp Vault: EC2 with Secrets from Vault

A practice project showing how Terraform can **read a secret from HashiCorp Vault** (KV v2 engine, AppRole auth) and use it while provisioning an **AWS EC2 instance**.

> ⚠️ **Learning project.** The secret is written into an EC2 tag only to show that the value was read. Do **not** put real secrets in tags (see [Security Notes](#security-notes)).

---

## Table of Contents

- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Vault Setup](#vault-setup)
- [Configuration](#configuration)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Security Notes](#security-notes)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

---

## Architecture

```
┌──────────────┐   1. AppRole login (role_id + secret_id)   ┌──────────────┐
│              │ ─────────────────────────────────────────▶ │              │
│  Terraform   │ ◀───────────────────────────────────────── │    Vault     │
│              │   2. Token  →  3. Read KV v2 secret        │   (KV v2)    │
└──────┬───────┘                                            └──────────────┘
       │
       │ 4. Create EC2 instance (secret value used in tags)
       ▼
┌──────────────┐
│   AWS EC2    │
│ (ap-south-1) │
└──────────────┘
```

1. The Vault provider logs in with **AppRole** (`auth/approle/login`).
2. Vault returns a token.
3. The `vault_kv_secret_v2` data source reads `<mount>/<secret_name>`.
4. The AWS provider creates an EC2 instance and tags it with a value from the secret.

---

## Project Structure

```
terraform-vault/
├── versions.tf          # Terraform & provider version constraints
├── variables.tf         # All input variable definitions
├── main.tf              # Providers, Vault data source, EC2 instance
├── outputs.tf           # Instance ID and private IP
├── example.tfvars       # Sample values: safe to commit
├── terraform.tfvars     # Real values: git-ignored, NEVER commit
├── .gitignore           # Keeps state, tfvars, and .terraform/ out of git
└── .terraform.lock.hcl  # Provider lock file: commit this
```

---

## Prerequisites

| Tool | Version |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | `>= 1.6` |
| AWS provider | `~> 6.0` (installed by `terraform init`) |
| Vault provider | `~> 5.0` (installed by `terraform init`) |
| A running Vault server | Reachable from the machine running Terraform |
| AWS account + credentials | Permission to create EC2 instances |

**AWS credentials:** configure them with any standard method, for example:

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

You also need an existing **subnet** in your VPC and an **AMI ID** that is valid in your chosen region.

---

## Vault Setup

Run these on your Vault server (or wherever you have the `vault` CLI and an admin token).

### 1. Enable a KV v2 secrets engine and store a secret

```bash
vault secrets enable -path=terraform_secret kv-v2

vault kv put terraform_secret/test-secret username="your-username"
```

### 2. Create a policy that lets Terraform read the secret

```bash
vault policy write terraform - <<EOF
path "terraform_secret/data/*" {
  capabilities = ["read"]
}
path "terraform_secret/metadata/*" {
  capabilities = ["read"]
}
# Needed if vault_skip_child_token = false
path "auth/token/create" {
  capabilities = ["update"]
}
EOF
```

### 3. Enable AppRole and create a role

```bash
vault auth enable approle

vault write auth/approle/role/terraform \
    token_policies="terraform" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=24h
```

### 4. Get the role ID and secret ID

```bash
vault read auth/approle/role/terraform/role-id
vault write -f auth/approle/role/terraform/secret-id
```

Keep both values for the [Configuration](#configuration) step.

---

## Configuration

### 1. Create your variables file

```bash
cp example.tfvars terraform.tfvars
```

Edit `terraform.tfvars` and fill in real values:

```hcl
aws_region    = "ap-south-1"
ami_id        = "ami-0123456789abcdef0"
instance_type = "t3.micro"
subnet_id     = "subnet-0123456789abcdef0"
instance_name = "ec2"

tags = {
  Environment = "dev"
  Owner       = "your-name"
}

vault_address     = "https://vault.example.com:8200"
vault_kv_mount    = "terraform_secret"
vault_secret_name = "test-secret"
vault_secret_key  = "username"
```

### 2. Provide the Vault credentials via environment variables (recommended)

Keep `vault_role_id` and `vault_secret_id` **out of files**:

**Bash / Git Bash**
```bash
export TF_VAR_vault_role_id="<role-id>"
export TF_VAR_vault_secret_id="<secret-id>"
```

**PowerShell**
```powershell
$env:TF_VAR_vault_role_id   = "<role-id>"
$env:TF_VAR_vault_secret_id = "<secret-id>"
```

> You *can* put them in `terraform.tfvars` (it is git-ignored), but environment variables are safer.

---

## Usage

```bash
# 1. Download providers
terraform init

# 2. Format and validate
terraform fmt
terraform validate

# 3. Preview changes
terraform plan

# 4. Apply
terraform apply
```

To use a different variables file (e.g. per environment):

```bash
terraform plan  -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

> `terraform.tfvars` and `*.auto.tfvars` are loaded automatically. Any other file name must be passed with `-var-file`.

---

## Inputs

### AWS

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `aws_region` | AWS region to deploy into | `string` | `"ap-south-1"` | no |
| `ami_id` | AMI ID for the EC2 instance (region-specific) | `string` | n/a | **yes** |
| `instance_type` | EC2 instance type | `string` | `"t3.micro"` | no |
| `subnet_id` | Subnet ID to launch the instance in | `string` | n/a | **yes** |
| `instance_name` | Value of the `Name` tag | `string` | `"ec2"` | no |
| `tags` | Extra tags merged onto the instance | `map(string)` | `{}` | no |

### Vault

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `vault_address` | Vault server address | `string` | n/a | **yes** |
| `vault_skip_child_token` | Use the AppRole token directly instead of creating a child token | `bool` | `true` | no |
| `vault_approle_login_path` | AppRole login path | `string` | `"auth/approle/login"` | no |
| `vault_role_id` | AppRole role ID (**sensitive**) | `string` | n/a | **yes** |
| `vault_secret_id` | AppRole secret ID (**sensitive**) | `string` | n/a | **yes** |
| `vault_kv_mount` | KV v2 mount path | `string` | n/a | **yes** |
| `vault_secret_name` | Secret name inside the mount | `string` | n/a | **yes** |
| `vault_secret_key` | Key in the secret whose value is read | `string` | `"username"` | no |

### How tags are built

```hcl
tags = merge(var.tags, {
  Name   = var.instance_name
  Secret = data.vault_kv_secret_v2.example.data[var.vault_secret_key]
})
```

`merge()` combines your optional `var.tags` with the fixed `Name` and `Secret` tags. When a key appears in both maps, the later map wins, so `var.tags` cannot override `Name` or `Secret`.

---

## Outputs

| Name | Description |
|---|---|
| `instance_id` | ID of the EC2 instance |
| `instance_private_ip` | Private IP of the EC2 instance |

```bash
terraform output
terraform output instance_id
```

---

## Security Notes

This is a learning project and has known weaknesses. Read these before reusing it.

| ⚠️ Issue | Why it matters | Recommended fix |
|---|---|---|
| **Secret stored in an EC2 tag** | Anyone with `ec2:DescribeInstances`/`DescribeTags` can read tags; they also appear in the console and CloudTrail | Deliver secrets at runtime (Vault Agent, SSM Parameter Store, Secrets Manager + IAM role) |
| **Secrets in Terraform state** | `sensitive = true` hides values in CLI output but **state is plain text** | Use a remote backend with encryption, e.g. S3 (`encrypt = true`) with locking |
| **Vault over HTTP** | Tokens and secrets travel unencrypted | Enable TLS on Vault and use an `https://` address |
| **Public Vault port** | Port 8200 open to the internet invites attacks | Restrict the security group to your IP or a VPN |
| **`skip_child_token = true`** | Terraform uses the AppRole token directly, with no separately revocable child token | Set to `false` and allow `auth/token/create` in the policy |
| **Default security group / unencrypted root volume** | Weak defaults on the EC2 instance | Add a dedicated `aws_security_group` and `root_block_device { encrypted = true }` |

### What must never be committed

The `.gitignore` already excludes:

- `*.tfstate`, `*.tfstate.*`: state contains secret values
- `*.tfvars` (except `example.tfvars`): real config and credentials
- `.terraform/`: provider binaries

If credentials were ever committed or shared, **rotate them**:

```bash
vault write -f auth/approle/role/terraform/secret-id          # issue new
vault write auth/approle/role/terraform/secret-id/destroy \
    secret_id="<old-secret-id>"                               # revoke old
```

### Example remote backend (recommended)

Add to `versions.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-bucket"
    key          = "terraform-vault/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Then run `terraform init -migrate-state`.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `data.vault_kv_secret_v2.example: Still reading...` then timeout | Vault is unreachable: check that the server is running, the address/IP is correct, and port 8200 is allowed in the security group |
| `permission denied` from Vault | The AppRole policy lacks `read` on `<mount>/data/*`, or the `secret_id` has expired (`secret_id_ttl`) |
| `invalid role or secret ID` | Wrong or expired `role_id`/`secret_id`: generate a new secret ID |
| `failed to create limited child token` | Set `vault_skip_child_token = true`, or allow `auth/token/create` in the policy |
| `InvalidAMIID.NotFound` | The AMI ID belongs to a different region than `aws_region` |
| `InvalidSubnetID.NotFound` | Subnet does not exist in the account/region |
| `No value for required variable` | Missing value in `terraform.tfvars` or the `TF_VAR_*` env var is not set in the current shell |
| `Warning: Deprecated Resource` on `vault_kv_secret_v2` | The data source still works; newer provider versions recommend the ephemeral KV v2 resource |

---

## Cleanup

Destroy all resources created by this project:

```bash
terraform destroy
```

Optionally remove the Vault test configuration:

```bash
vault kv metadata delete terraform_secret/test-secret
vault delete auth/approle/role/terraform
vault policy delete terraform
```
