output "cluster_name" {
  description = "Nom du cluster K8s"
  value       = scaleway_k8s_cluster.main.name
}

output "kubeconfig_command" {
  description = "Commande pour récupérer le kubeconfig"
  value       = "scw k8s kubeconfig install ${scaleway_k8s_cluster.main.id}"
}

output "app_prod_url" {
  value = "https://gestion-produits.local"
}

output "app_dev_url" {
  value = "https://dev.gestion-produits.local"
}
