variable "scw_access_key" {
  description = "Scaleway Access Key"
  type        = string
  sensitive   = true
}

variable "scw_secret_key" {
  description = "Scaleway Secret Key"
  type        = string
  sensitive   = true
}

variable "scw_project_id" {
  description = "Scaleway Project ID"
  type        = string
}

variable "scw_zone" {
  description = "Scaleway Zone"
  type        = string
  default     = "fr-par-1"
}

variable "scw_region" {
  description = "Scaleway Region"
  type        = string
  default     = "fr-par"
}

variable "db_password" {
  description = "Mot de passe MySQL (prod)"
  type        = string
  sensitive   = true
}

variable "dev_db_password" {
  description = "Mot de passe PostgreSQL (dev)"
  type        = string
  sensitive   = true
}

variable "docker_hub_user" {
  description = "Nom d'utilisateur Docker Hub"
  type        = string
  default     = "gregoiremouilleau"
}
