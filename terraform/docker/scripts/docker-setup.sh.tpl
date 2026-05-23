#!/bin/bash
# Script de provisioning cloud-init pour la VM Docker
set -e

export DEBIAN_FRONTEND=noninteractive

# Mise à jour système
apt-get update && apt-get upgrade -y

# Installation Docker Engine
curl -fsSL https://get.docker.com | sh

# Installation Docker Compose plugin
apt-get install -y docker-compose-plugin git

# Cloner le projet
cd /opt
git clone https://github.com/Gregoire-Mouilleau/Conteneurisation_avancee.git app
cd app/gestion-produits

# Créer le .env
cat > .env << 'EOF'
DB_NAME=gestion_produits
DB_USER=root
DB_PASSWORD=${db_password}
DEV_DB_NAME=gestion_produits
DEV_DB_USER=gpuser
DEV_DB_PASSWORD=${dev_db_password}
EOF

# Générer les certificats TLS
docker run --rm -v $(pwd)/nginx/certs:/certs alpine sh -c "
  apk add --no-cache openssl && \
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /certs/prod.key -out /certs/prod.crt \
    -subj '/CN=gestion-produits.local' && \
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /certs/dev.key -out /certs/dev.crt \
    -subj '/CN=dev.gestion-produits.local'
"

# Démarrer l'application
docker compose up -d --build

echo "Déploiement terminé"
