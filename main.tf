
# Prerequisites:
# `LINODE_TOKEN` env var must be set.

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "2.7.1"
    }
  }

  cloud {
    organization = "bobwhitelock"

    workspaces {
      name = "personal-infra"
    }
  }
}

variable "LINODE_TOKEN" {
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

resource "linode_instance" "web_server" {
  label           = "web_server"
  image           = local.web_server_image
  region          = "eu-west"
  type            = "g6-nanode-1"
  authorized_keys = [local.personal_ssh_public_key]
  stackscript_id  = linode_stackscript.web_server_bootstrap.id
  stackscript_data = {
    PERSONAL_SSH_PUBLIC_KEY = local.personal_ssh_public_key
  }
}

output "ip" {
  value = local.web_server_ip
}

output "data_warehouse_dokku_remote" {
  # TODO Automatically set this as the remote on GitHub.
  value = "${replace(local.web_server_ip, ".", "-")}.ip.linodeusercontent.com:data-warehouse"
}
