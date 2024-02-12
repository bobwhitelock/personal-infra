
terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "2.14.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.25.0"
    }
  }

  cloud {
    organization = "bobwhitelock"

    workspaces {
      name = "personal-infra"
    }
  }
}

provider "aws" {
  # Use Ireland as S3 pricing here looks the same as `us-east-1` (whereas
  # London pricing is not), but usually has better latency for me.
  region = "eu-west-1"
}

variable "GITHUB_TOKEN" {
  type = string
}

variable "LINODE_TOKEN" {
  type = string
}

variable "NETLIFY_TOKEN" {
  type = string
}

variable "DATASETTE_BOB_PASSWORD_HASH" {
  type = string
}

variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}

locals {
  web_server_image = "linode/ubuntu22.04"
  web_server_ip    = linode_instance.web_server.ip_address

  personal_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC3DJvy3N7izwrMsYXlvkO4DGL+1hEv0om6AnJIXUgSGhhKwfFeqKBK3aevqPLA86kS/43uhL2BT35nf3JFdtqg1TcLYzBHDDjpPZBDWIjrQyqvCKUuGL4a698Uu5EZ/MgxBnM8BBA90+Y2qLXhbq6ttSywrzAAIlVXCCaU6i6vWz7XyQhWlb0kOzgjVR7OHI9CJ433Fbdp1QXpZ2iMgRJdP2V2BiYE3LjjoMaF1GqhrKOMHlxJlVXarNh4OmKq3xfv5kKGYjGiZZOpxZmB2kBkSvJdVxMTCED9ume+KqD2cqmbPTx4WA56Ms5nqUl92gT6h730B4PBkMTcgWqcgUzf+JApbWINc0bOwsjTfr6GTI8xoaZGz4kNJ42cepwqzgQ6zfFHoJowVdkp9sMM2xAIGQ4BMnhbOiiAIUdprkJm94qSo+ZBlNcjdwCytpfVJwP4u2f24EZEVU6eGW7ptzdMg5MAvGt3ZIkHhLhbdrVV9JQTwUwkGFbykhXkRhElRNLzdqKox6JwKr+0NjHkILYSOp+GFkt2EyZRDo7nv6TE6Etge6TMi9XFIOsPjQY0eg4HnJHbXkn9Z+LDhgxYsDOR3fym9VCYY7bIX2MuRO0JJ+cy9hK8AwnQynXPJ/85AdSQCAhfIaUebLTmF9mF9DaCI/dnW/wDln3+HfR35pgHhQ== bob.whitelock1@gmail.com"
}

resource "linode_stackscript" "web_server_bootstrap" {
  label       = "web_server_bootstrap"
  description = "Sets up the web_server instance"
  script      = file("web_server_bootstrap.sh")
  images      = [local.web_server_image]
}

resource "linode_stackscript" "replace_netlify_dns_record" {
  label       = "replace_netlify_dns_record"
  description = "Helper script; replaces a Netlify DNS record"
  script      = file("libexec/replace_netlify_dns_record.py")
  images      = [local.web_server_image]
}

resource "linode_instance" "web_server" {
  label           = "web_server"
  image           = local.web_server_image
  region          = "eu-west"
  type            = "g6-nanode-1"
  authorized_keys = [local.personal_ssh_public_key]
  stackscript_id  = linode_stackscript.web_server_bootstrap.id
  stackscript_data = {
    PERSONAL_SSH_PUBLIC_KEY                   = local.personal_ssh_public_key
    REPLACE_NETLIFY_DNS_RECORD_STACKSCRIPT_ID = linode_stackscript.replace_netlify_dns_record.id

    GITHUB_TOKEN__PASSWORD      = var.GITHUB_TOKEN
    _LINODE_TOKEN__PASSWORD     = var.LINODE_TOKEN
    NETLIFY_TOKEN__PASSWORD     = var.NETLIFY_TOKEN
    DATASETTE_BOB_PASSWORD_HASH = var.DATASETTE_BOB_PASSWORD_HASH
  }
}

resource "aws_s3_bucket" "personal_data" {
  bucket = "bobwhitelock-personal-data"
}

resource "aws_s3_bucket_versioning" "personal_data_versioning" {
  bucket = aws_s3_bucket.personal_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "ip" {
  value = local.web_server_ip
}
