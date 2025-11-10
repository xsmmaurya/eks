# Phase 7.2 — Policy (Kyverno)

Use **Kyverno** to enforce safe-by-default pod settings across the cluster while keeping exceptions local to `apps` as needed.

## Install Kyverno (controller + CLI)
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace

# (optional) kyverno CLI for testing policies locally
brew install kyverno
```
## Apply our org policies
```bash
kubectl apply -k srotas/policy/kyverno
```

## Exceptions
Use **PolicyException** to allow specific workloads to bypass a rule:
```yaml
apiVersion: kyverno.io/v2alpha1
kind: PolicyException
metadata:
  name: allow-write-fs-for-init
  namespace: apps
spec:
  match:
    any:
      - resources:
          kinds: ["Pod"]
          namespaces: ["apps"]
          names: ["srotas-main-*"]
  exceptions:
    - policyName: readonly-rootfs
      ruleNames: ["enforce-readonly-rootfs"]
```
