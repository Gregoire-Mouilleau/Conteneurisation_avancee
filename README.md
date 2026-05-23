# Gestion Produits — Déploiement conteneurisé

Application PHP/MySQL de gestion de produits, déployée avec Docker et Kubernetes, avec version dev PostgreSQL.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │           Nginx (80/443)                │
                    │    Reverse proxy + TLS auto-signé       │
                    └──────────────┬──────────────────────────┘
                                   │
               ┌───────────────────┴──────────────────┐
               │                                      │
    ┌──────────▼──────────┐               ┌──────────▼──────────┐
    │    PHP/Apache        │               │    PHP/Apache        │
    │  (prod) pdo_mysql    │               │   (dev) pdo_pgsql   │
    └──────────┬──────────┘               └──────────┬──────────┘
               │                                      │
    ┌──────────▼──────────┐               ┌──────────▼──────────┐
    │      MySQL 8.4       │               │   PostgreSQL 17     │
    │  gestion_produits   │               │  gestion_produits   │
    └─────────────────────┘               └─────────────────────┘
```

## Prérequis

- Docker Desktop (ou Docker Engine + Compose plugin)
- Terraform >= 1.3 (pour le déploiement infrastructure)
- kubectl (pour Kubernetes)

## Structure du projet

```
gestion-produits/
├── php/                    # Image PHP prod (pdo_mysql)
│   ├── Dockerfile
│   └── www/                # Sources PHP (modifiées : connect.php via env vars)
├── php-pgsql/              # Image PHP dev (pdo_pgsql, colonnes lowercase)
│   ├── Dockerfile
│   └── www/
├── mysql/                  # Image MySQL avec dump initial
│   ├── Dockerfile
│   └── gestion_produits.sql
├── postgresql/
│   └── init.sql            # Schéma PostgreSQL adapté
├── nginx/
│   ├── conf.d/             # prod.conf + dev.conf
│   ├── certs/              # Certificats TLS (générés, gitignorés)
│   └── generate-certs.sh
├── kubernetes/
│   ├── prod/               # Namespace, Secret, PVC, Deployments, Services, Ingress
│   ├── dev/                # Idem pour PostgreSQL
│   └── generate-tls-secrets.sh
└── terraform/
    ├── docker/             # OCI VM A1.Flex (Always Free) + provisioning Docker
    └── kubernetes/         # OCI 3× A1.Flex kubeadm + Helm + déploiement
```

## Déploiement Docker (local)

### 1. Générer les certificats TLS
```bash
docker run --rm -v $(pwd)/nginx/certs:/certs alpine sh -c "
  apk add --no-cache openssl
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /certs/prod.key -out /certs/prod.crt -subj '/CN=gestion-produits.local'
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /certs/dev.key -out /certs/dev.crt -subj '/CN=dev.gestion-produits.local'
"
```

### 2. Configurer les variables d'environnement
```bash
cp .env.example .env
# Éditer .env avec les mots de passe souhaités
```

### 3. Ajouter les entrées DNS locales
**Linux/Mac** — `/etc/hosts` :
```
127.0.0.1 gestion-produits.local
127.0.0.1 dev.gestion-produits.local
```
**Windows** — `C:\Windows\System32\drivers\etc\hosts` :
```
127.0.0.1 gestion-produits.local
127.0.0.1 dev.gestion-produits.local
```

### 4. Démarrer
```bash
docker compose up -d --build
```

- **Production** : https://gestion-produits.local (admin / password)
- **Dev (PostgreSQL)** : https://dev.gestion-produits.local

## Mise à jour de l'application

```bash
# Rebuild les images + redémarrage sans interruption
docker compose up -d --build php-prod
docker compose up -d --build php-dev
```

## Déploiement Kubernetes

### Prérequis : kubeconfig configuré

```bash
export KUBECONFIG=/chemin/vers/kubeconfig
```

### 1. Déploiement prod + dev

```bash
kubectl apply -f kubernetes/prod/
kubectl apply -f kubernetes/dev/
bash kubernetes/generate-tls-secrets.sh
```

### 2. Ajouter l'IP du Load Balancer dans /etc/hosts

```bash
LB_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$LB_IP gestion-produits.local dev.gestion-produits.local"
```

## Infrastructure Terraform (Oracle Cloud Free Tier)

Les deux infrastructures utilisent **Oracle Cloud Always Free** — aucun coût.

### Prérequis OCI (à faire une seule fois)

1. Créer un compte sur [cloud.oracle.com](https://cloud.oracle.com) (gratuit)
2. Générer une clé API : *Profile → API Keys → Add API Key*
3. Télécharger la clé `.pem` dans `~/.oci/oci_api_key.pem`
4. Noter : Tenancy OCID, User OCID, Fingerprint (affichés après création de la clé)
5. Avoir une paire de clés SSH : `~/.ssh/id_rsa` + `~/.ssh/id_rsa.pub`

### Docker (OCI VM A1.Flex — 1 OCPU / 6 GB)

```bash
cd terraform/docker
cp terraform.tfvars.example terraform.tfvars
# Remplir oci_tenancy_ocid, oci_user_ocid, oci_fingerprint, ssh_public_key, mots de passe
terraform init
terraform apply
```

Terraform crée automatiquement :
- 1 VM ARM64 `VM.Standard.A1.Flex` (Ubuntu 22.04, 1 OCPU / 6 GB)
- VCN + sous-réseau public + règles pare-feu (22/80/443)
- cloud-init : installe Docker, clone le repo, génère les TLS, lance `docker compose up`

**Après `terraform apply`**, récupérer l'IP en sortie et ajouter dans `/etc/hosts` :
```
<IP_DOCKER> gestion-produits.local dev.gestion-produits.local
```

### Kubernetes (OCI — 3 nœuds A1.Flex kubeadm)

```bash
cd terraform/kubernetes
cp terraform.tfvars.example terraform.tfvars
# Remplir les mêmes variables OCI + ssh_private_key_path
terraform init
terraform apply
```

Terraform crée automatiquement :
- 3 VM ARM64 `VM.Standard.A1.Flex` : 1 master + 2 workers (1 OCPU / 6 GB chacun)
- Cluster kubeadm v1.29 + CNI Flannel
- Nginx Ingress Controller (DaemonSet hostNetwork — ports 80/443 natifs)
- Longhorn 1.6.2 (stockage partagé RWX)
- Déploiement de l'application prod + dev avec TLS auto-signés

**Après `terraform apply`**, récupérer l'IP d'un worker et ajouter dans `/etc/hosts` :
```
<IP_WORKER1> gestion-produits.local dev.gestion-produits.local
```

Pour accéder au cluster localement :
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<IP_MASTER> 'cat ~/.kube/config' > ~/.kube/config-gp
export KUBECONFIG=~/.kube/config-gp
kubectl get nodes
```

Terraform crée automatiquement :
- Un cluster Kapsule 3 nœuds (DEV1-M)
- Nginx Ingress Controller (Helm)
- Longhorn pour le stockage partagé (Helm)
- Déploiement de l'application sur le cluster

## Images Docker Hub

| Image | Description |
|-------|-------------|
| `gregoiremouilleau/gestion-produits-php:latest` | PHP 8.2 + Apache + pdo_mysql (multi-arch amd64/arm64) |
| `gregoiremouilleau/gestion-produits-mysql:latest` | MySQL 8.4 avec données initiales (multi-arch amd64/arm64) |
| `gregoiremouilleau/gestion-produits-php-pgsql:latest` | PHP 8.2 + Apache + pdo_pgsql (multi-arch amd64/arm64) |

## Choix techniques

| Composant | Technologie | Justification |
|-----------|-------------|---------------|
| Reverse proxy | Nginx | Léger, performant, SSL natif |
| BDD prod | MySQL 8.4 | Compatibilité native avec l'app |
| BDD dev | PostgreSQL 17 | Démonstration portabilité BDD |
| Orchestration K8s | kubeadm v1.29 | Cluster auto-géré sur OCI Free Tier |
| Storage K8s | Longhorn 1.6.2 | Stockage partagé RWX pour uploads |
| IaC | Terraform + OCI Provider | Infrastructure Always Free, zéro coût |
| TLS | Auto-signé (OpenSSL) | Résolution locale sans domaine public |
