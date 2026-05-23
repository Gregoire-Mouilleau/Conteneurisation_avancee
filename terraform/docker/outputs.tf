output "docker_vm_ip" {
  description = "IP publique de la VM Docker"
  value       = scaleway_instance_ip.docker_ip.address
}

output "app_prod_url" {
  description = "URL de l'application en production"
  value       = "https://gestion-produits.local (ajouter ${scaleway_instance_ip.docker_ip.address} dans /etc/hosts)"
}

output "app_dev_url" {
  description = "URL de la version dev"
  value       = "https://dev.gestion-produits.local (ajouter ${scaleway_instance_ip.docker_ip.address} dans /etc/hosts)"
}
