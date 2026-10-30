provider "aws" {
  region = var.aws_region
}

provider "vault" {
  address          = var.vault_address
  skip_child_token = var.vault_skip_child_token

  auth_login {
    path = var.vault_approle_login_path

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

data "vault_kv_secret_v2" "example" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_name
}

resource "aws_instance" "my_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = merge(var.tags, {
    Name   = var.instance_name
    Secret = data.vault_kv_secret_v2.example.data[var.vault_secret_key]
  })
}
