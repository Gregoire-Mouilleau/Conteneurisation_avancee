terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "oci" {
  tenancy_ocid     = var.oci_tenancy_ocid
  user_ocid        = var.oci_user_ocid
  fingerprint      = var.oci_fingerprint
  private_key_path = var.oci_private_key_path
  region           = var.oci_region
}

# ── Availability domains ─────────────────────────────────────────────────────
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

# ── Image Ubuntu 22.04 ARM64 ─────────────────────────────────────────────────
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.oci_compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ── VCN ──────────────────────────────────────────────────────────────────────
resource "oci_core_vcn" "docker_vcn" {
  compartment_id = var.oci_compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "gestion-produits-docker-vcn"
  dns_label      = "dockervcn"
}

# ── Internet Gateway ─────────────────────────────────────────────────────────
resource "oci_core_internet_gateway" "docker_igw" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.docker_vcn.id
  display_name   = "docker-igw"
  enabled        = true
}

# ── Route Table ──────────────────────────────────────────────────────────────
resource "oci_core_route_table" "docker_rt" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.docker_vcn.id
  display_name   = "docker-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.docker_igw.id
  }
}

# ── Security List ────────────────────────────────────────────────────────────
resource "oci_core_security_list" "docker_sl" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.docker_vcn.id
  display_name   = "docker-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 22;  max = 22  }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 80;  max = 80  }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 443; max = 443 }
  }
}

# ── Subnet public ────────────────────────────────────────────────────────────
resource "oci_core_subnet" "docker_subnet" {
  compartment_id    = var.oci_compartment_id
  vcn_id            = oci_core_vcn.docker_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "docker-subnet"
  dns_label         = "dockersubnet"
  route_table_id    = oci_core_route_table.docker_rt.id
  security_list_ids = [oci_core_security_list.docker_sl.id]
}

# ── VM Docker (A1.Flex : 1 OCPU / 6 GB — Always Free) ───────────────────────
resource "oci_core_instance" "docker_server" {
  compartment_id      = var.oci_compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "gestion-produits-docker"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.docker_subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/scripts/docker-setup.sh.tpl", {
      db_password     = var.db_password
      dev_db_password = var.dev_db_password
    }))
  }
}

output "docker_server_ip" {
  description = "Adresse IP publique du serveur Docker"
  value       = oci_core_instance.docker_server.public_ip
}

output "hosts_file_entry" {
  description = "Entrées à ajouter dans /etc/hosts (ou C:\\Windows\\System32\\drivers\\etc\\hosts)"
  value       = "${oci_core_instance.docker_server.public_ip} gestion-produits.local dev.gestion-produits.local"
}
