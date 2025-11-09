#!/usr/bin/env bash
set -euo pipefail

### ────────────────────────────────────────────────
### Colors / helpers
### ────────────────────────────────────────────────
green()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[1;33m%s\033[0m\n" "$*"; }
red()    { printf "\033[1;31m%s\033[0m\n" "$*"; }

trap 'red "❌ Setup failed at line $LINENO"' ERR

### ────────────────────────────────────────────────
### Phase 0 — Pre-flight checks
### ────────────────────────────────────────────────
green "==> Phase 0: verifying dependencies"

for cmd in docker kubectl minikube; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    red "Missing required tool: $cmd"
    echo "→ Install via Homebrew: brew install $cmd"
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  red "Docker engine not running. Start Docker Desktop or Colima first."
  exit 1
fi

### ────────────────────────────────────────────────
### Phase 1 — Reset existing cluster
### ────────────────────────────────────────────────
green "==> Phase 1: hard-reset any existing minikube cluster"

if pgrep -f "minikube tunnel" >/dev/null 2>&1; then
  yellow "   • Stopping existing minikube tunnel"
  pkill -f "minikube tunnel" || true
fi

yellow "   • Deleting old minikube cluster (if exists)"
minikube delete || true

yellow "   • Cleaning up old kube-context"
kubectl config delete-context  minikube     2>/dev/null || true
kubectl config delete-cluster  minikube     2>/dev/null || true
kubectl config unset users.minikube         2>/dev/null || true

# Optional cleanup
# docker system prune -f >/dev/null 2>&1 || true

### ────────────────────────────────────────────────
### Phase 2 — Create fresh cluster (EKS-style)
### ────────────────────────────────────────────────
green "==> Phase 2: creating fresh minikube cluster with Calico CNI"

minikube start \
  --driver=docker \
  --kubernetes-version=v1.30.0 \
  --cpus=6 \
  --memory=12000 \
  --cni=calico

### ────────────────────────────────────────────────
### Phase 3 — Enable system addons
### ────────────────────────────────────────────────
green "==> Phase 3: enabling core addons"
minikube addons enable metrics-server

### ────────────────────────────────────────────────
### Phase 4 — Cluster health check
### ────────────────────────────────────────────────
green "==> Phase 4: waiting for cluster health"

kubectl wait --for=condition=Ready node/minikube --timeout=180s
kubectl -n kube-system wait --for=condition=Ready pod \
  -l k8s-app=calico-node --timeout=300s

### ────────────────────────────────────────────────
### Phase 5 — Summary
### ────────────────────────────────────────────────
green "==> Phase 5: summary"
kubectl get nodes -o wide
echo
kubectl get pods -A | sed -n '1,200p'
echo
green "✅  Cluster is clean and EKS-like."
yellow "👉  For LoadBalancer services later, open another terminal and run:"
yellow "     sudo -E minikube tunnel"
