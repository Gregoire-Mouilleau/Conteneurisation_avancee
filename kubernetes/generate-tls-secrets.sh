#!/bin/bash
# Génère des certificats TLS auto-signés et crée les secrets K8s dans les deux namespaces
set -e

# Prod
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/prod.key -out /tmp/prod.crt \
  -subj "/CN=gestion-produits.local"

kubectl create secret tls gestion-produits-tls \
  --cert=/tmp/prod.crt --key=/tmp/prod.key \
  -n gestion-produits-prod --dry-run=client -o yaml | kubectl apply -f -

# Dev
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/dev.key -out /tmp/dev.crt \
  -subj "/CN=dev.gestion-produits.local"

kubectl create secret tls gestion-produits-dev-tls \
  --cert=/tmp/dev.crt --key=/tmp/dev.key \
  -n gestion-produits-dev --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets TLS créés"
