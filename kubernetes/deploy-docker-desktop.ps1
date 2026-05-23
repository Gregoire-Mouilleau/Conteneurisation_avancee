# Deploy gestion-produits on Docker Desktop Kubernetes
# Run this script AFTER enabling Kubernetes in Docker Desktop settings

$ErrorActionPreference = "Stop"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Switch to docker-desktop context
Write-Host "Switching to docker-desktop context..."
kubectl config use-context docker-desktop

# 2. Install Nginx Ingress Controller
Write-Host "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
Write-Host "Waiting for Nginx Ingress to be ready..."
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# 3. Generate TLS certs and create K8s TLS secrets
Write-Host "Generating TLS certificates..."
$certsDir = "$env:TEMP\k8s-certs"
New-Item -ItemType Directory -Force -Path $certsDir | Out-Null

docker run --rm -v "${certsDir}:/certs" alpine sh -c `
  "apk add --no-cache openssl 2>/dev/null && `
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /certs/prod.key -out /certs/prod.crt -subj '/CN=gestion-produits.local' 2>/dev/null && `
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /certs/dev.key -out /certs/dev.crt -subj '/CN=dev.gestion-produits.local' 2>/dev/null && echo done"

# 4. Apply namespaces first
Write-Host "Creating namespaces..."
kubectl apply -f "$SCRIPT_DIR/prod/namespace.yml"
kubectl apply -f "$SCRIPT_DIR/dev/namespace.yml"

# 5. Create TLS secrets
Write-Host "Creating TLS secrets..."
kubectl create secret tls gestion-produits-tls `
  --cert="$certsDir/prod.crt" --key="$certsDir/prod.key" `
  --namespace=gestion-produits-prod --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls gestion-produits-dev-tls `
  --cert="$certsDir/dev.crt" --key="$certsDir/dev.key" `
  --namespace=gestion-produits-dev --dry-run=client -o yaml | kubectl apply -f -

# 6. Deploy prod
Write-Host "Deploying PROD (MySQL + PHP)..."
kubectl apply -f "$SCRIPT_DIR/prod/secret.yml"
kubectl apply -f "$SCRIPT_DIR/prod/pvc-bdd.yml"
kubectl apply -f "$SCRIPT_DIR/prod/pvc-uploads.yml"
kubectl apply -f "$SCRIPT_DIR/prod/deployment-bdd.yml"
kubectl apply -f "$SCRIPT_DIR/prod/service-bdd.yml"
kubectl apply -f "$SCRIPT_DIR/prod/deployment-php.yml"
kubectl apply -f "$SCRIPT_DIR/prod/service-php.yml"
kubectl apply -f "$SCRIPT_DIR/prod/ingress.yml"

# 7. Deploy dev
Write-Host "Deploying DEV (PostgreSQL + PHP)..."
kubectl apply -f "$SCRIPT_DIR/dev/secret.yml"
kubectl apply -f "$SCRIPT_DIR/dev/configmap-pgsql.yml"
kubectl apply -f "$SCRIPT_DIR/dev/pvc-pgsql.yml"
kubectl apply -f "$SCRIPT_DIR/dev/pvc-uploads.yml"
kubectl apply -f "$SCRIPT_DIR/dev/deployment-pgsql.yml"
kubectl apply -f "$SCRIPT_DIR/dev/service-pgsql.yml"
kubectl apply -f "$SCRIPT_DIR/dev/deployment-php.yml"
kubectl apply -f "$SCRIPT_DIR/dev/service-php.yml"
kubectl apply -f "$SCRIPT_DIR/dev/ingress.yml"

# 8. Status
Write-Host ""
Write-Host "=== Deployment complete ==="
kubectl get pods -n gestion-produits-prod
kubectl get pods -n gestion-produits-dev
Write-Host ""
Write-Host "Add to C:\Windows\System32\drivers\etc\hosts (as admin):"
Write-Host "  127.0.0.1 gestion-produits.local"
Write-Host "  127.0.0.1 dev.gestion-produits.local"
Write-Host ""
Write-Host "Access: https://gestion-produits.local"
Write-Host "        https://dev.gestion-produits.local"
