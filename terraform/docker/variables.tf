variable "oci_tenancy_ocid" {
  description = "OCID du tenancy Oracle Cloud"
  type        = string
}

variable "oci_user_ocid" {
  description = "OCID de l'utilisateur Oracle Cloud"
  type        = string
}

variable "oci_fingerprint" {
  description = "Fingerprint de la clé API Oracle Cloud"
  type        = string
}

variable "oci_private_key_path" {
  description = "Chemin vers la clé privée API Oracle Cloud (.pem)"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "oci_region" {
  description = "Région Oracle Cloud (ex: eu-frankfurt-1, us-ashburn-1)"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "oci_compartment_id" {
  description = "OCID du compartiment (= oci_tenancy_ocid pour un compte free tier)"
  type        = string
}

variable "ssh_public_key" {
  description = "Clé SSH publique pour accès aux VMs (contenu de ~/.ssh/id_rsa.pub)"
  type        = string
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
