#!/bin/sh
# Génère les certificats TLS auto-signés pour prod et dev
set -e

CERTS_DIR="$(dirname "$0")/certs"
mkdir -p "$CERTS_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERTS_DIR/prod.key" \
  -out    "$CERTS_DIR/prod.crt" \
  -subj "/CN=gestion-produits.local"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERTS_DIR/dev.key" \
  -out    "$CERTS_DIR/dev.crt" \
  -subj "/CN=dev.gestion-produits.local"

echo "Certificats générés dans $CERTS_DIR"
