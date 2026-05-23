terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.40"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
  required_version = ">= 1.3.0"
}

provider "scaleway" {
  access_key = var.scw_access_key
  secret_key = var.scw_secret_key
  project_id = var.scw_project_id
  zone       = var.scw_zone
  region     = var.scw_region
}

# ── Cluster Kubernetes Kapsule ───────────────────────────────────────────────
resource "scaleway_k8s_cluster" "main" {
  name    = "gestion-produits-cluster"
  version = "1.30"
  cni     = "cilium"

  autoscaler_config {
    disable_scale_down              = false
    scale_down_delay_after_add      = "5m"
    scale_down_unneeded_time        = "5m"
    estimator                       = "binpacking"
    expander                        = "random"
    ignore_daemonsets_utilization   = true
    balance_similar_node_groups     = true
    expendable_pods_priority_cutoff = -10
  }

  delete_additional_resources = true

  tags = ["gestion-produits", "k8s"]
}

# ── Pool de nœuds — 3 workers ────────────────────────────────────────────────
resource "scaleway_k8s_pool" "workers" {
  cluster_id = scaleway_k8s_cluster.main.id
  name       = "workers"
  node_type  = "DEV1-M"    # 3 vCPU, 4 GB RAM
  size       = 3
  min_size   = 3
  max_size   = 5

  autoscaling = false
  autohealing = true
}

# ── Providers configurés dynamiquement depuis le kubeconfig ──────────────────
provider "kubernetes" {
  host                   = scaleway_k8s_cluster.main.kubeconfig[0].host
  token                  = scaleway_k8s_cluster.main.kubeconfig[0].token
  cluster_ca_certificate = base64decode(scaleway_k8s_cluster.main.kubeconfig[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = scaleway_k8s_cluster.main.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.main.kubeconfig[0].token
    cluster_ca_certificate = base64decode(scaleway_k8s_cluster.main.kubeconfig[0].cluster_ca_certificate)
  }
}

# ── Nginx Ingress Controller ─────────────────────────────────────────────────
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  depends_on = [scaleway_k8s_pool.workers]
}

# ── Longhorn (stockage partagé) ──────────────────────────────────────────────
resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true
  version          = "1.6.2"

  depends_on = [scaleway_k8s_pool.workers]
}

# ── Déploiement de l'application ─────────────────────────────────────────────
resource "null_resource" "deploy_app" {
  depends_on = [helm_release.nginx_ingress, helm_release.longhorn]

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=$(mktemp)
      echo '${scaleway_k8s_cluster.main.kubeconfig[0].config_file}' > $KUBECONFIG
      kubectl apply -f ${path.module}/../../kubernetes/prod/
      kubectl apply -f ${path.module}/../../kubernetes/dev/
      bash ${path.module}/../../kubernetes/generate-tls-secrets.sh
    EOT
  }
}
