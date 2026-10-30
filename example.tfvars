# Example variable values

# ---------- AWS ----------
aws_region    = "ap-south-1"
ami_id        = "ami-xxxxxxxxxxxxxxxxx"
instance_type = "t3.micro"
subnet_id     = "subnet-xxxxxxxxxxxxxxxxx"
instance_name = "ec2"

tags = {
  Environment = "dev"
  Owner       = "your-name"
}

# ---------- Vault ----------
vault_address            = "https://vault.example.com:8200"
vault_skip_child_token   = true
vault_approle_login_path = "auth/approle/login"
vault_kv_mount           = "terraform_secret"
vault_secret_name        = "test-secret"
vault_secret_key         = "username"
