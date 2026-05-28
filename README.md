# Gestion Produits — Déploiement conteneurisé

Application PHP/MySQL de gestion de produits déployée sur un VPS OVH (Ubuntu 24.04, `51.178.80.212`) avec deux environnements conteneurisés coexistants : **Docker Compose** et **Kubernetes (k3d 3 nœuds)**.

---

## Accès rapide — serveur de démonstration

### 1. Ajouter dans le fichier `hosts`

**Windows** — `C:\Windows\System32\drivers\etc\hosts` :
```
51.178.80.212 gestion-produits.local
51.178.80.212 dev.gestion-produits.local
```

**Linux/Mac** — `/etc/hosts` :
```
51.178.80.212 gestion-produits.local
51.178.80.212 dev.gestion-produits.local
```

### 2. URLs d'accès

| Environnement | URL Prod (MySQL) | URL Dev (PostgreSQL) |
|---|---|---|
| **Kubernetes** (k3d) | https://gestion-produits.local | https://dev.gestion-produits.local |
| **Docker Compose** | https://gestion-produits.local:8443 | https://dev.gestion-produits.local:8443 |

> Les certificats TLS sont auto-signés → accepter l'avertissement du navigateur.
>
> **Note ports Docker Compose :** Les deux environnements coexistant sur le même VPS, k3d occupe les ports 80/443. Docker Compose utilise donc 8080/8443. Pour tester Docker Compose sur les ports 80/443 standard, arrêter k3d au préalable (voir section [Basculer entre les environnements](#basculer-entre-les-environnements)).

### 3. Identifiants

| Login | Mot de passe |
|-------|-------------|
| `admin` | `password` |

---

## Architecture

```
         OVH VPS — 51.178.80.212 (Ubuntu 24.04, 6 vCores, 12 GB RAM)
         ┌────────────────────────────────────────────────────────┐
         │                                                        │
         │  ┌──────────────────────────────────────────────┐      │
         │  │  k3d (k3s in Docker) — 3 nœuds               │      │
         │  │  ports 80/443  →  Traefik Ingress            │      │
         │  │                                              │      │
         │  │  Namespace gestion-produits-prod             │      │
         │  │    PHP (x2) → MySQL 8.4  [PVC local-path]    │      │
         │  │  Namespace gestion-produits-dev              │      │
         │  │    PHP (x2) → PostgreSQL 17  [PVC]           │      │
         │  └──────────────────────────────────────────────┘      │
         │                                                        │
         │  ┌──────────────────────────────────────────────┐      │
         │  │  Docker Compose — ports 8080/8443            │      │
         │  │  Nginx (reverse proxy TLS auto-signé)        │      │
         │  │  ├── php-prod → MySQL 8.4   (volume nommé)   │      │
         │  │  └── php-dev  → PostgreSQL 17 (volume nommé) │      │
         │  └──────────────────────────────────────────────┘      │
         └────────────────────────────────────────────────────────┘
```

---

## Conteneurisation de l'application

### Adaptations réalisées

L'application source utilise des constantes PHP hardcodées pour la connexion BDD. Elle a été adaptée pour lire la configuration depuis des **variables d'environnement** (`DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`).

#### Image PHP prod — `gregoiremouilleau/gestion-produits-php:latest`

- Base : `php:8.2-apache`
- Extensions : `pdo`, `pdo_mysql`
- Répertoire `uploads/` créé avec droits d'écriture
- Source : `php/Dockerfile`

#### Image PHP dev — `gregoiremouilleau/gestion-produits-php-pgsql:latest`

- Base : `php:8.2-apache`
- Extensions : `pdo`, `pdo_pgsql`
- Schéma adapté : colonnes en minuscules pour PostgreSQL, types compatibles
- Source : `php-pgsql/Dockerfile`

#### Image MySQL — `gregoiremouilleau/gestion-produits-mysql:latest`

- Base : `mysql:8.4`
- Dump initial inclus (`mysql/gestion_produits.sql`) chargé automatiquement au premier démarrage
- Source : `mysql/Dockerfile`

#### Images multi-architecture

Toutes les images sont buildées pour `linux/amd64` et `linux/arm64` :

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t gregoiremouilleau/gestion-produits-php:latest --push php/
docker buildx build --platform linux/amd64,linux/arm64 \
  -t gregoiremouilleau/gestion-produits-php-pgsql:latest --push php-pgsql/
docker buildx build --platform linux/amd64,linux/arm64 \
  -t gregoiremouilleau/gestion-produits-mysql:latest --push mysql/
```

---

## Structure du projet

```
gestion-produits/
├── php/                    # Image PHP prod (pdo_mysql)
│   ├── Dockerfile
│   └── www/                # Sources PHP adaptées (variables d'env)
├── php-pgsql/              # Image PHP dev (pdo_pgsql)
│   ├── Dockerfile
│   └── www/                # Sources adaptées PostgreSQL
├── mysql/                  # Image MySQL 8.4 avec données initiales
│   ├── Dockerfile
│   └── gestion_produits.sql
├── postgresql/
│   └── init.sql            # Schéma PostgreSQL adapté (colonnes lowercase)
├── nginx/
│   ├── conf.d/
│   │   ├── prod.conf       # Virtual host gestion-produits.local (HTTPS/443)
│   │   └── dev.conf        # Virtual host dev.gestion-produits.local (HTTPS/443)
│   ├── certs/              # Certificats TLS auto-signés (gitignorés)
│   └── generate-certs.sh
├── kubernetes/
│   ├── prod/               # Namespace, Secret, PVC, Deployments (x2), Services, Ingress
│   ├── dev/                # Namespace, Secret, PVC, Deployments, Services, Ingress
│   └── generate-tls-secrets.sh
├── terraform/
│   ├── docker/             # OCI VM A1.Flex + provisioning Docker Compose
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
│   └── kubernetes/         # OCI 3x A1.Flex + kubeadm
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars.example
├── docker-compose.yml
└── .env.example
```

---

## Déploiement Docker Compose

### Prérequis

- Docker Engine + Compose plugin
- `openssl` disponible

### 1. Cloner le dépôt

```bash
git clone https://github.com/Gregoire-Mouilleau/Conteneurisation_avancee.git
cd Conteneurisation_avancee/gestion-produits
```

### 2. Configurer les variables d'environnement

```bash
cp .env.example .env
# Éditer .env : DB_NAME, DB_USER, DB_PASSWORD, DEV_DB_NAME, DEV_DB_USER, DEV_DB_PASSWORD
```

### 3. Générer les certificats TLS

```bash
bash nginx/generate-certs.sh
```

Ou manuellement :

```bash
mkdir -p nginx/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/prod.key -out nginx/certs/prod.crt \
  -subj '/CN=gestion-produits.local'
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/dev.key -out nginx/certs/dev.crt \
  -subj '/CN=dev.gestion-produits.local'
```

### 4. Démarrer

```bash
docker compose up -d
```

Services démarrés :
- `nginx` — reverse proxy HTTPS (ports 8080/8443 en coexistence avec k3d, ou 80/443 en standalone)
- `php-prod` — application PHP + pdo_mysql
- `db` — MySQL 8.4 avec données initiales chargées automatiquement
- `php-dev` — application PHP + pdo_pgsql
- `postgres` — PostgreSQL 17

### 5. Vérifier

```bash
docker compose ps
docker compose logs nginx
```

---

## Basculer entre les environnements

Sur le VPS de démonstration, k3d et Docker Compose coexistent. Pour tester Docker Compose sur les ports **80/443** standard :

```bash
# Arrêter k3d (libère les ports 80/443)
sudo k3d cluster stop gestion-produits

# Reconfigurer Docker Compose sur 80/443
# Modifier dans docker-compose.yml : "80:80" et "443:443"
sudo docker compose down
sudo docker compose up -d

# Pour remettre k3d en service
sudo docker compose down
sudo k3d cluster start gestion-produits
```

---

## Déploiement Kubernetes (k3d — 3 nœuds)

Le cluster k3d simule un vrai cluster Kubernetes avec **1 nœud control-plane + 2 agents** tournant dans des conteneurs Docker sur un seul VPS.

### Créer le cluster

```bash
k3d cluster create gestion-produits \
  --servers 1 --agents 2 \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer"
```

Vérifier les 3 nœuds :

```bash
kubectl get nodes
# NAME                                STATUS   ROLES
# k3d-gestion-produits-server-0       Ready    control-plane
# k3d-gestion-produits-agent-0        Ready    <none>
# k3d-gestion-produits-agent-1        Ready    <none>
```

### Générer les secrets TLS

```bash
bash kubernetes/generate-tls-secrets.sh
```

### Déployer prod (MySQL) et dev (PostgreSQL)

```bash
kubectl apply -f kubernetes/prod/
kubectl apply -f kubernetes/dev/
```

Manifestes déployés :
- `namespace.yml` — isolation des environnements
- `secret.yml` — identifiants BDD encodés base64
- `pvc-bdd.yml` / `pvc-uploads.yml` — stockage persistant (local-path)
- `deployment-php.yml` — 2 réplicas PHP en prod, 1 en dev
- `deployment-bdd.yml` — MySQL 8.4 (prod) / `deployment-pgsql.yml` — PostgreSQL 17 (dev)
- `service-php.yml` / `service-bdd.yml` (prod) — `service-pgsql.yml` (dev) — services ClusterIP internes
- `ingress.yml` — routage Traefik avec TLS (ports 80/443)

### Stockage partagé (PersistentVolumeClaims)

Le stockage est géré par le **local-path provisioner** intégré à k3d/k3s. Il provisionne automatiquement des `PersistentVolume` sur le nœud hôte. Les données MySQL, PostgreSQL et les uploads PHP sont persistés dans des volumes dédiés.

```bash
kubectl get pvc -n gestion-produits-prod
kubectl get pvc -n gestion-produits-dev
```

### Vérifier le déploiement

```bash
kubectl get pods -n gestion-produits-prod
kubectl get pods -n gestion-produits-dev
kubectl get ingress -A
```

### Injecter les données initiales MySQL (si nécessaire)

```bash
MYSQL_POD=$(kubectl get pod -n gestion-produits-prod -l app=db \
  -o jsonpath='{.items[0].metadata.name}')
tail -n +2 mysql/gestion_produits.sql | \
  kubectl exec -i -n gestion-produits-prod $MYSQL_POD -- \
  sh -c 'mysql -uroot -pEpsi2026!Prod'
```

---

## Mise à jour de l'application

### Version dev — migration MySQL vers PostgreSQL

La version dev démontre la **portabilité de l'application** vers une autre base de données sans modifier le code métier.

| Aspect | Prod | Dev |
|--------|------|-----|
| BDD | MySQL 8.4 | PostgreSQL 17 |
| Extension PHP | `pdo_mysql` | `pdo_pgsql` |
| Image PHP | `gestion-produits-php` | `gestion-produits-php-pgsql` |
| URL Docker | `gestion-produits.local:8443` | `dev.gestion-produits.local:8443` |
| URL K8s | `gestion-produits.local` | `dev.gestion-produits.local` |

### Mettre à jour les images (rebuild + push)

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t gregoiremouilleau/gestion-produits-php:latest --push php/
docker buildx build --platform linux/amd64,linux/arm64 \
  -t gregoiremouilleau/gestion-produits-php-pgsql:latest --push php-pgsql/
```

### Mettre à jour Docker Compose

```bash
docker compose pull          # Récupère les nouvelles images depuis Docker Hub
docker compose up -d         # Redémarre les services mis à jour
```

### Mettre à jour Kubernetes

```bash
kubectl rollout restart deployment/php-prod -n gestion-produits-prod
kubectl rollout restart deployment/php-dev -n gestion-produits-dev

# Suivre le rollout (rolling update sans interruption)
kubectl rollout status deployment/php-prod -n gestion-produits-prod
kubectl rollout status deployment/php-dev -n gestion-produits-dev
```

---

## Infrastructure Terraform (Oracle Cloud — IaC)

> **Note :** Le code Terraform est complet et `terraform plan` s'exécute sans erreur.
> L'application `terraform apply` est bloquée par une **saturation des capacités ARM A1.Flex**
> dans la région `eu-paris-1` (erreur OCI : `Out of host capacity`).
> Cette contrainte est temporaire et indépendante du code. Le déploiement a donc été réalisé
> manuellement sur un VPS OVH comme alternative.

### Prérequis OCI

1. Créer un compte sur [cloud.oracle.com](https://cloud.oracle.com)
2. Générer une clé API : *Profile → API Keys → Add API Key*
3. Télécharger la clé `.pem` dans `~/.oci/oci_api_key.pem`
4. Renseigner les OCIDs dans `terraform.tfvars` (copier depuis `terraform.tfvars.example`)

### Terraform Docker (1 VM A1.Flex)

```bash
cd terraform/docker
cp terraform.tfvars.example terraform.tfvars
# Remplir : tenancy_ocid, user_ocid, fingerprint, region, ssh_public_key, mots de passe
terraform init
terraform plan   # ✅ fonctionne (6 resources to add)
terraform apply  # ⚠️ bloqué : Out of host capacity en eu-paris-1
```

Ressources déclarées :
- 1 VM ARM64 `VM.Standard.A1.Flex` (1 OCPU / 6 GB RAM, Ubuntu 22.04)
- VCN + sous-réseau public + Internet Gateway
- Security List : ports 22, 80, 443, 8080, 8443
- `cloud_init` : installe Docker + Compose, clone le repo, génère les certs TLS, `docker compose up -d`

### Terraform Kubernetes (3 VMs A1.Flex — kubeadm)

```bash
cd terraform/kubernetes
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan   # ✅ fonctionne
terraform apply  # ⚠️ bloqué : Out of host capacity en eu-paris-1
```

Ressources déclarées :
- 3 VMs ARM64 `VM.Standard.A1.Flex` : 1 control-plane + 2 workers (1 OCPU / 6 GB chacun)
- VCN + réseau dédié cluster
- `cloud_init` master : kubeadm init, CNI Flannel, Traefik Ingress Controller
- `cloud_init` workers : kubeadm join automatique
- Déploiement des manifestes K8s via `remote-exec`

---

## Images Docker Hub

| Image | Description |
|-------|-------------|
| `gregoiremouilleau/gestion-produits-php:latest` | PHP 8.2 + Apache + pdo_mysql (multi-arch amd64/arm64) |
| `gregoiremouilleau/gestion-produits-mysql:latest` | MySQL 8.4 avec données initiales (multi-arch amd64/arm64) |
| `gregoiremouilleau/gestion-produits-php-pgsql:latest` | PHP 8.2 + Apache + pdo_pgsql (multi-arch amd64/arm64) |

---

## Choix techniques

| Composant | Technologie | Justification |
|-----------|-------------|---------------|
| Hébergement | VPS OVH (Ubuntu 24.04, 6 vCores, 12 GB) | Serveur dédié accessible publiquement, Terraform bloqué par capacité OCI |
| Reverse proxy | Nginx | Léger, performant, terminaison TLS native |
| BDD prod | MySQL 8.4 | Compatibilité native avec l'application source |
| BDD dev | PostgreSQL 17 | Démonstration portabilité multi-BDD |
| Orchestration K8s | k3d (k3s in Docker) | Cluster 3 nœuds sur VPS unique, léger et rapide |
| Ingress K8s | Traefik (intégré k3d) | Natif k3s, routage par hostname + TLS |
| Stockage K8s | local-path provisioner | PVC automatiques, persistance des données BDD et uploads |
| IaC | Terraform + OCI Provider | Always Free Tier
| TLS | Auto-signé (OpenSSL) | Résolution locale sans achat de domaine |
| Images | Docker Hub multi-arch | Compatibilité amd64 (x86) + arm64 (VPS OVH) |
| Résolution DNS | fichier hosts | Accessible depuis n'importe quel poste sans serveur DNS |

