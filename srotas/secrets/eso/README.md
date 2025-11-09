# Phase 7.4 — Secrets Sync (External Secrets Operator)

## What
Use **External Secrets Operator (ESO)** to **sync secrets from a provider** (AWS Secrets Manager in EKS; a local Kubernetes Secret in Minikube) into namespace-scoped Kubernetes `Secret`s for your apps.

## Why
- Single source of truth in cloud (ASM) while keeping local dev simple.
- No app code changes; secrets arrive as normal K8s Secrets.
- Easy rotation: update at the provider; ESO refreshes the synced Secret.

## Will
- One **ClusterSecretStore** for AWS Secrets Manager (`aws-asm`).
- One **ClusterSecretStore** for local dev using a Kubernetes Secret (`local-kubernetes`).
- **ExternalSecret** objects to materialize app secrets (`srotas-main-env`, `redis-auth`).

---

## Install ESO (once per cluster)
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets   -n external-secrets --create-namespace
kubectl -n external-secrets get pods
```

> Keep policies strict: ESO control-plane runs in `external-secrets` ns. If Kyverno blocks it, add overrides/exception for that namespace (same as KEDA).

---

## Apply this phase
```bash
# Add the bootstrap local dev secret once (for minikube)
kubectl apply -f srotas/secrets/eso/bootstrap-dev-secrets.yaml

# Then the stores + ExternalSecrets
kubectl apply -k srotas/secrets/eso
```

---

## EKS (IRSA) notes
In EKS, prefer **IRSA**:
1. Create IAM policy to read specific ASM secrets.
2. Create IAM role for service account (IRSA) and annotate ESO's service account.
3. Switch `auth` in `secretstore-aws-asm.yaml` to `serviceAccountRef`.

