# ---------- AWS ----------
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (region-specific)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID to launch the EC2 instance in"
  type        = string
}

variable "instance_name" {
  description = "Value of the Name tag on the EC2 instance"
  type        = string
  default     = "ec2"
}

variable "tags" {
  description = "Additional tags to apply to the EC2 instance"
  type        = map(string)
  default     = {}
}

# ---------- Vault ----------
variable "vault_address" {
  description = "Vault server address, e.g. https://vault.example.com:8200"
  type        = string
}

variable "vault_skip_child_token" {
  description = "Use the AppRole token directly instead of creating a child token"
  type        = bool
  default     = true
}

variable "vault_approle_login_path" {
  description = "Vault AppRole login path"
  type        = string
  default     = "auth/approle/login"
}

variable "vault_role_id" {
  description = "Vault AppRole role_id (prefer setting via TF_VAR_vault_role_id)"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "Vault AppRole secret_id (prefer setting via TF_VAR_vault_secret_id)"
  type        = string
  sensitive   = true
}

variable "vault_kv_mount" {
  description = "KV v2 secrets engine mount path"
  type        = string
}

variable "vault_secret_name" {
  description = "Name of the secret within the KV v2 mount"
  type        = string
}

variable "vault_secret_key" {
  description = "Key inside the secret whose value is read"
  type        = string
  default     = "username"
}
