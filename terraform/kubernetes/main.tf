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

# ── Data sources ─────────────────────────────────────────────────────────────
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

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
resource "oci_core_vcn" "k8s_vcn" {
  compartment_id = var.oci_compartment_id
  cidr_block     = "10.1.0.0/16"
  display_name   = "gestion-produits-k8s-vcn"
  dns_label      = "k8svcn"
}

# ── Internet Gateway ─────────────────────────────────────────────────────────
resource "oci_core_internet_gateway" "k8s_igw" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s-igw"
  enabled        = true
}

# ── Route Table ──────────────────────────────────────────────────────────────
resource "oci_core_route_table" "k8s_rt" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.k8s_igw.id
  }
}

# ── Security List ────────────────────────────────────────────────────────────
resource "oci_core_security_list" "k8s_sl" {
  compartment_id = var.oci_compartment_id
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "k8s-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Trafic interne VCN (inter-noeuds K8s + Flannel + Longhorn)
  ingress_security_rules {
    protocol = "all"
    source   = "10.1.0.0/16"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 22;    max = 22    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 6443;  max = 6443  }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 80;    max = 80    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 443;   max = 443   }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 30000; max = 32767 }
  }
}

# ── Subnet public ────────────────────────────────────────────────────────────
resource "oci_core_subnet" "k8s_subnet" {
  compartment_id    = var.oci_compartment_id
  vcn_id            = oci_core_vcn.k8s_vcn.id
  cidr_block        = "10.1.1.0/24"
  display_name      = "k8s-subnet"
  dns_label         = "k8ssubnet"
  route_table_id    = oci_core_route_table.k8s_rt.id
  security_list_ids = [oci_core_security_list.k8s_sl.id]
}

# ── Cloud-init commun a tous les noeuds ──────────────────────────────────────
locals {
  k8s_cloud_init = base64encode(file("${path.module}/scripts/setup-k8s-node.sh"))
}

# ── Noeud master (A1.Flex : 1 OCPU / 6 GB -- Always Free) ───────────────────
resource "oci_core_instance" "master" {
  compartment_id      = var.oci_compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "k8s-master"
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
    subnet_id        = oci_core_subnet.k8s_subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.k8s_cloud_init
  }
}

# ── Noeud worker 1 ───────────────────────────────────────────────────────────
resource "oci_core_instance" "worker1" {
  compartment_id      = var.oci_compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "k8s-worker1"
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
    subnet_id        = oci_core_subnet.k8s_subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.k8s_cloud_init
  }
}

# ── Noeud worker 2 ───────────────────────────────────────────────────────────
resource "oci_core_instance" "worker2" {
  compartment_id      = var.oci_compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "k8s-worker2"
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
    subnet_id        = oci_core_subnet.k8s_subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.k8s_cloud_init
  }
}

# ── Copie cle SSH sur le master (master -> workers via IP privee) ─────────────
resource "null_resource" "copy_ssh_key" {
  depends_on = [oci_core_instance.master]

  connection {
    type        = "ssh"
    host        = oci_core_instance.master.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Attente cloud-init master...'; sleep 15; done",
      "echo 'Cloud-init master termine.'"
    ]
  }

  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/.ssh/k8s_key"
  }

  provisioner "remote-exec" {
    inline = ["chmod 600 /home/ubuntu/.ssh/k8s_key"]
  }
}

# ── Initialisation kubeadm sur le master ─────────────────────────────────────
resource "null_resource" "master_init" {
  depends_on = [null_resource.copy_ssh_key]

  connection {
    type        = "ssh"
    host        = oci_core_instance.master.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "20m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${oci_core_instance.master.private_ip} --control-plane-endpoint=${oci_core_instance.master.public_ip}:6443 2>&1 | tee /tmp/kubeadm-init.log",
      "mkdir -p $HOME/.kube",
      "sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown ubuntu:ubuntu $HOME/.kube/config",
      "kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.25.1/kube-flannel.yml",
      "kubectl wait node/$(hostname) --for=condition=Ready --timeout=120s",
      "kubeadm token create --print-join-command > /tmp/join.sh",
      "chmod +x /tmp/join.sh",
    ]
  }
}

# ── Jonction des workers au cluster ──────────────────────────────────────────
resource "null_resource" "workers_join" {
  depends_on = [
    null_resource.master_init,
    oci_core_instance.worker1,
    oci_core_instance.worker2
  ]

  connection {
    type        = "ssh"
    host        = oci_core_instance.master.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "20m"
  }

  provisioner "remote-exec" {
    inline = [
      # Worker 1
      "ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s_key ubuntu@${oci_core_instance.worker1.private_ip} 'while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 15; done'",
      "scp -o StrictHostKeyChecking=no -i ~/.ssh/k8s_key /tmp/join.sh ubuntu@${oci_core_instance.worker1.private_ip}:/tmp/join.sh",
      "ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s_key ubuntu@${oci_core_instance.worker1.private_ip} 'sudo bash /tmp/join.sh'",
      # Worker 2
      "ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s_key ubuntu@${oci_core_instance.worker2.private_ip} 'while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 15; done'",
      "scp -o StrictHostKeyChecking=no -i ~/.ssh/k8s_key /tmp/join.sh ubuntu@${oci_core_instance.worker2.private_ip}:/tmp/join.sh",
      "ssh -o StrictHostKeyChecking=no -i ~/.ssh/k8s_key ubuntu@${oci_core_instance.worker2.private_ip} 'sudo bash /tmp/join.sh'",
      # Verifier les 3 noeuds
      "kubectl wait nodes --all --for=condition=Ready --timeout=180s",
    ]
  }
}

# ── Helm + Nginx Ingress (hostNetwork ports 80/443) + Longhorn ───────────────
resource "null_resource" "helm_install" {
  depends_on = [null_resource.workers_join]

  connection {
    type        = "ssh"
    host        = oci_core_instance.master.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "20m"
  }

  provisioner "remote-exec" {
    inline = [
      # Installer Helm
      "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",

      # Nginx Ingress en mode hostNetwork (ports 80/443 directement sur le noeud)
      "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx",
      "helm repo update",
      "helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace --version 4.10.0 --set controller.kind=DaemonSet --set controller.hostNetwork=true --set controller.service.type=ClusterIP --set controller.dnsPolicy=ClusterFirstWithHostNet --set controller.tolerations[0].key=node-role.kubernetes.io/control-plane --set controller.tolerations[0].operator=Exists --set controller.tolerations[0].effect=NoSchedule",
      "kubectl rollout status daemonset/ingress-nginx-controller -n ingress-nginx --timeout=120s",

      # Longhorn
      "helm repo add longhorn https://charts.longhorn.io",
      "helm upgrade --install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.6.2",
      "kubectl rollout status deployment/longhorn-ui -n longhorn-system --timeout=300s",
    ]
  }
}

# ── Deploiement de l'application ──────────────────────────────────────────────
resource "null_resource" "deploy_app" {
  depends_on = [null_resource.helm_install]

  connection {
    type        = "ssh"
    host        = oci_core_instance.master.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/Gregoire-Mouilleau/Conteneurisation_avancee.git /tmp/gp-app",

      # Adapter les PVC pour Longhorn (ReadWriteMany)
      "find /tmp/gp-app/gestion-produits/kubernetes -name '*.yml' -exec sed -i 's/storageClassName: hostpath/storageClassName: longhorn/g; s/ReadWriteOnce/ReadWriteMany/g' {} +",

      # Namespaces
      "kubectl create namespace gestion-produits-prod --dry-run=client -o yaml | kubectl apply -f -",
      "kubectl create namespace gestion-produits-dev  --dry-run=client -o yaml | kubectl apply -f -",

      # Certificats TLS auto-signes
      "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/prod.key -out /tmp/prod.crt -subj '/CN=gestion-produits.local'",
      "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/dev.key  -out /tmp/dev.crt  -subj '/CN=dev.gestion-produits.local'",

      # Secrets TLS
      "kubectl create secret tls gestion-produits-tls     --cert=/tmp/prod.crt --key=/tmp/prod.key -n gestion-produits-prod --dry-run=client -o yaml | kubectl apply -f -",
      "kubectl create secret tls gestion-produits-dev-tls --cert=/tmp/dev.crt  --key=/tmp/dev.key  -n gestion-produits-dev  --dry-run=client -o yaml | kubectl apply -f -",

      # Deploiement
      "kubectl apply -f /tmp/gp-app/gestion-produits/kubernetes/prod/",
      "kubectl apply -f /tmp/gp-app/gestion-produits/kubernetes/dev/",

      # Statut
      "kubectl get pods --all-namespaces",
    ]
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "master_public_ip" {
  value = oci_core_instance.master.public_ip
}

output "worker1_public_ip" {
  value = oci_core_instance.worker1.public_ip
}

output "worker2_public_ip" {
  value = oci_core_instance.worker2.public_ip
}

output "hosts_file_entry" {
  description = "Entrees a ajouter dans /etc/hosts (utiliser l'IP d'un worker)"
  value       = "${oci_core_instance.worker1.public_ip} gestion-produits.local dev.gestion-produits.local"
}

output "kubeconfig_command" {
  description = "Commande pour recuperer le kubeconfig en local"
  value       = "ssh -i <SSH_PRIVATE_KEY> ubuntu@${oci_core_instance.master.public_ip} 'cat ~/.kube/config'"
}
