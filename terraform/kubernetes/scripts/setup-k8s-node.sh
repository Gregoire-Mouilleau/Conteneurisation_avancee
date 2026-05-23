#!/bin/bash
# Cloud-init : installation des prérequis Kubernetes sur chaque nœud Ubuntu 22.04 ARM64
set -e

export DEBIAN_FRONTEND=noninteractive

# ── Désactivation du swap (obligatoire pour kubelet) ─────────────────────────
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ── Modules noyau ─────────────────────────────────────────────────────────────
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# ── Paramètres réseau pour K8s ────────────────────────────────────────────────
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# ── Désactiver le pare-feu (OCI gère les règles via Security List) ────────────
ufw disable || true
iptables -P FORWARD ACCEPT

# ── Installation de containerd ────────────────────────────────────────────────
apt-get update -y
apt-get install -y ca-certificates curl gnupg apt-transport-https

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y containerd.io

# ── Configuration containerd avec SystemdCgroup ───────────────────────────────
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# ── Installation kubeadm / kubelet / kubectl (v1.29) ─────────────────────────
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
  | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# ── Prérequis Longhorn ────────────────────────────────────────────────────────
apt-get install -y open-iscsi nfs-common
systemctl enable --now iscsid

# ── Outils divers ─────────────────────────────────────────────────────────────
apt-get install -y git openssl

echo "=== Prérequis Kubernetes installés avec succès ==="
