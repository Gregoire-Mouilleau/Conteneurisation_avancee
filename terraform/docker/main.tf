terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.40"
    }
  }
  required_version = ">= 1.3.0"
}

provider "scaleway" {
  access_key      = var.scw_access_key
  secret_key      = var.scw_secret_key
  project_id      = var.scw_project_id
  zone            = var.scw_zone
  region          = var.scw_region
}

# ── Réseau privé ────────────────────────────────────────────────────────────
resource "scaleway_vpc_private_network" "main" {
  name = "gestion-produits-net"
}

# ── IP publique ─────────────────────────────────────────────────────────────
resource "scaleway_instance_ip" "docker_ip" {}

# ── VM Docker ───────────────────────────────────────────────────────────────
resource "scaleway_instance_server" "docker" {
  name  = "gestion-produits-docker"
  type  = "DEV1-S"           # 2 vCPU, 2 GB RAM
  image = "ubuntu_jammy"

  ip_id = scaleway_instance_ip.docker_ip.id

  private_network {
    pn_id = scaleway_vpc_private_network.main.id
  }

  user_data = {
    cloud-init = templatefile("${path.module}/scripts/docker-setup.sh.tpl", {
      db_password     = var.db_password
      dev_db_password = var.dev_db_password
      docker_hub_user = var.docker_hub_user
    })
  }

  tags = ["docker", "gestion-produits"]
}

# ── Security group ──────────────────────────────────────────────────────────
resource "scaleway_instance_security_group" "docker_sg" {
  name                    = "gestion-produits-docker-sg"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    port     = 22
    protocol = "TCP"
  }
  inbound_rule {
    action   = "accept"
    port     = 80
    protocol = "TCP"
  }
  inbound_rule {
    action   = "accept"
    port     = 443
    protocol = "TCP"
  }
}

resource "scaleway_instance_security_group_rules" "docker_sg_rules" {
  security_group_id = scaleway_instance_security_group.docker_sg.id
}
