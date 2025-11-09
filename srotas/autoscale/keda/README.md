# Phase 7.3 — Event‑Driven Autoscaling (KEDA)

## What
Use **KEDA** to scale deployments based on *external event signals* (e.g., Redis queue depth), not just CPU/Memory.

## Why
- Your `srotas-ms-mcp` service likely processes background work; queue depth is a better signal than CPU.
- Keeps costs low at idle; bursts quickly when traffic spikes.

## Will
- A `ScaledObject` will autoscale `srotas-ms-mcp` between min/max replicas based on **Redis list length**.
- Uses a `TriggerAuthentication` wired to a Secret for the Redis password.
- Works alongside default HPAs without conflict (KEDA manages the HPA it creates).

## Install KEDA (once per cluster)
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm upgrade --install keda kedacore/keda -n keda --create-namespace
```

## Apply this phase
```bash
kubectl apply -k srotas/autoscale/keda
```
