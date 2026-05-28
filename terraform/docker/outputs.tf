output "docker_vm_ip" {
  description = "IP publique de la VM Docker"
  value       = oci_core_instance.docker_server.public_ip
}

output "app_prod_url" {
  description = "URL de l'application en production"
  value       = "https://gestion-produits.local (ajouter ${oci_core_instance.docker_server.public_ip} dans /etc/hosts)"
}

output "app_dev_url" {
  description = "URL de la version dev"
  value       = "https://dev.gestion-produits.local (ajouter ${oci_core_instance.docker_server.public_ip} dans /etc/hosts)"
}
