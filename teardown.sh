#!/usr/bin/env bash
set -euo pipefail

### ────────────────────────────────────────────────
### Colors / helpers
### ────────────────────────────────────────────────
green()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[1;33m%s\033[0m\n" "$*"; }
red()    { printf "\033[1;31m%s\033[0m\n" "$*"; }

trap 'red "❌ Teardown failed at line $LINENO"' ERR

CONFIRM="ask"
if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
  CONFIRM="yes"
fi

confirm() {
  if [[ "$CONFIRM" == "yes" ]]; then return 0; fi
  read -r -p "This will delete the Minikube cluster and kubeconfig entries. Continue? [y/N] " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { yellow "Skipping $2 (missing $1)"; return 1; }
}

### ────────────────────────────────────────────────
### Phase 0 — Pre-flight (optional)
### ────────────────────────────────────────────────
need_cmd kubectl "kubeconfig cleanup"
need_cmd minikube "cluster deletion"
need_cmd pkill "tunnel stop" >/dev/null 2>&1 || true
need_cmd pgrep "tunnel detect" >/dev/null 2>&1 || true

### ────────────────────────────────────────────────
### Phase 1 — Confirm
### ────────────────────────────────────────────────
if ! confirm; then
  yellow "Aborted by user."
  exit 0
fi

### ────────────────────────────────────────────────
### Phase 2 — Stop any running minikube tunnel
### ────────────────────────────────────────────────
green "==> Phase 2: stopping minikube tunnel (if running)"
if pgrep -f "minikube tunnel" >/dev/null 2>&1; then
  yellow "   • Killing existing 'minikube tunnel' process"
  pkill -f "minikube tunnel" || true
else
  yellow "   • No tunnel process found"
fi

### ────────────────────────────────────────────────
### Phase 3 — Delete the Minikube cluster
### ────────────────────────────────────────────────
green "==> Phase 3: deleting Minikube cluster"
if command -v minikube >/dev/null 2>&1; then
  minikube delete || true
else
  yellow "   • minikube not installed; skipping delete"
fi

### ────────────────────────────────────────────────
### Phase 4 — Clean kubeconfig entries
### ────────────────────────────────────────────────
green "==> Phase 4: cleaning kubeconfig (context/cluster/user)"
if command -v kubectl >/dev/null 2>&1; then
  kubectl config delete-context minikube     2>/dev/null || true
  kubectl config delete-cluster minikube     2>/dev/null || true
  kubectl config unset users.minikube        2>/dev/null || true
else
  yellow "   • kubectl not installed; skipping kubeconfig cleanup"
fi

### ────────────────────────────────────────────────
### Phase 5 — Optional Docker cleanup (commented)
### ────────────────────────────────────────────────
# green "==> Phase 5: optional Docker prune (commented out by default)"
# docker system prune -f >/dev/null 2>&1 || true

### ────────────────────────────────────────────────
### Phase 6 — Summary
### ────────────────────────────────────────────────
green "✅ Teardown complete."
yellow "• If you had a separate terminal running 'sudo -E minikube tunnel', you can close it now."
yellow "• Your kubeconfig no longer contains the 'minikube' context."
