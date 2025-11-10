# 🧭 EKS-Local-to-Cloud Roadmap  
### Learn, Build & Mirror Real AWS EKS on Your Mac

---

## 🌱 Phase 0 — Local Tooling & Cluster Setup

### 🎯 Goal
Prepare your Mac for a full Kubernetes/EKS-style workflow.

### 🧰 Tools
| Purpose | Local Tool | AWS Equivalent |
|----------|-------------|----------------|
| Container runtime | Docker Desktop / Colima | ECR + ECS Agent |
| Local K8s cluster | Minikube | EKS Control Plane |
| CLI | kubectl, helm, k9s, jq, yq, mkcert | eksctl, kubectl, AWS CLI |
| CNI | Calico | AWS VPC CNI |
| Ingress | Traefik | ALB / NLB |
| Storage | OpenEBS LocalPV | EBS CSI Driver |
| TLS Certificates | cert-manager + mkcert | AWS ACM |
| Logs | Loki + Promtail | CloudWatch Logs |
| Metrics | Prometheus + Grafana | CloudWatch Metrics |
| GitOps | ArgoCD | CodePipeline / ArgoCD on EKS |

### 🚀 Commands
```bash
brew install docker kubectl helm minikube k9s jq yq mkcert
minikube start --driver=docker --cni=calico --cpus=6 --memory=12000
🏗️ Phase 1 — Namespace, RBAC & Base Services
🎯 Goal
Create apps namespace, ServiceAccount, Roles, and base Deployments.

📂 Folder layout
arduino
Copy code
srotas/
  infra/
  rbac/
  secrets/
  config/
  apps/
  services/
  networking/
  logs/
⚙️ Commands
kubectl apply -f infra/namespace.yaml
kubectl apply -f rbac/app-serviceaccount.yaml
kubectl -n apps get sa,role,rolebinding
🧩 Phase 2 — Storage (EBS ➜ OpenEBS LocalPV)
🎯 Goal
Provision dynamic storage for Postgres PVCs.

🧱 Steps
helm repo add openebs https://openebs.github.io/charts
helm upgrade --install openebs openebs/openebs \
  -n openebs --create-namespace \
  --set engines.local.hostpathClass.enabled=true
kubectl get sc
🧠 Mapping
Local	AWS Equivalent
OpenEBS LocalPV	EBS CSI Driver
StorageClass	EBS volume type (gp3, io2)
PVC	EBS Volume Claim

🌐 Phase 3 — Networking (Ingress + TLS + Traefik)
🎯 Goal
Expose apps externally with HTTPS.

🛠️ Steps
Install cert-manager + mkcert

Create root CA:

mkcert -install
CAROOT=$(mkcert -CAROOT)
kubectl -n cert-manager create secret tls mkcert-root-ca \
  --cert="$CAROOT/rootCA.pem" \
  --key="$CAROOT/rootCA-key.pem"
Create ClusterIssuer referencing mkcert-root-ca

Install Traefik via Helm:

helm repo add traefik https://traefik.github.io/charts
helm upgrade --install traefik traefik/traefik \
  -n networking --create-namespace \
  --set service.type=LoadBalancer
Add certificate + ingress for:

https://srotas.127.0.0.1.nip.io → FE

https://api.srotas.127.0.0.1.nip.io → main

https://mcp.srotas.127.0.0.1.nip.io → ms-mcp

Run tunnel:

sudo -E minikube tunnel
🧠 Mapping
Local	AWS
Traefik	ALB/NLB
cert-manager	ACM
mkcert CA	ACM Private CA
nip.io DNS	Route53 Hosted Zone
minikube tunnel	AWS Load Balancer Controller

🔒 Phase 4 — Security & Network Policies
🎯 Goal
Apply least-privilege access and isolate pods.

🔐 Examples
allow-only-srotas-main-to-mcp.yaml

netpol-allow-dns.yaml

🧠 Mapping
Local	AWS
NetworkPolicy	Security Group rules
ServiceAccount + RoleBinding	IAM Role + Policy
Secret (Opaque)	Secrets Manager / Parameter Store
ConfigMap	SSM Parameters

🧩 Phase 5 — Observability (Metrics + Logs)
🎯 Goal
Visualize metrics and logs.

🛠️ Stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki-stack \
  -n monitoring --set grafana.enabled=false
Access Grafana:

kubectl -n monitoring port-forward svc/kube-prom-stack-grafana 3000:80
# user: admin / pass: prom-operator
🧠 Mapping
Local	AWS
Prometheus + Grafana	CloudWatch Metrics / Managed Prometheus
Loki + Promtail	CloudWatch Logs Insights
Alertmanager	SNS / CloudWatch Alarms

🔁 Phase 6 — GitOps (ArgoCD)
🎯 Goal
Automate deploys from Git repos.

⚙️ Steps
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace
kubectl -n argocd port-forward svc/argocd-server 8080:80
🧠 Mapping
Local	AWS
ArgoCD	CodePipeline / ArgoCD on EKS
GitHub repo	CodeCommit / GitHub Actions
Helm / Kustomize	CloudFormation / CDK pipelines


🧩 Phase 7 — Extra Layers (Advanced)
Layer	Tool	AWS Equivalent
Service Mesh	Istio / Linkerd	App Mesh
Policy	Kyverno / Gatekeeper	OPA / IAM conditions
Event Autoscaling	KEDA	CloudWatch / Lambda triggers
Secrets Sync	External Secrets Operator	Secrets Manager sync


🧠 Phase 8 — Cloud Parity: From Minikube ➜ EKS
Steps to migrate
Push containers to ECR:

docker buildx build --platform linux/amd64,linux/arm64 \
  -t <acct>.dkr.ecr.<region>.amazonaws.com/srotas-main:0.1.0 --push .
Create EKS cluster:

eksctl create cluster --name srotas-eks --region ap-south-1 --nodes 3
Install add-ons:

AWS Load Balancer Controller

EBS CSI Driver

CloudWatch Agent / Prometheus

cert-manager (ACM issuer)

Apply manifests:

kubectl apply -f srotas/
Switch DNS via Route53.

Move observability to CloudWatch.

Point ArgoCD to EKS context.


💰 Phase 9 — Cost & Scaling Learnings
Local concept	AWS concept	Key Learning
minikube tunnel	ALB cost	Understand per-LB hourly charges
OpenEBS volumes	EBS	Volume sizing & IOPS (gp3 vs io2)
Prometheus retention	CloudWatch retention	Data lifecycle policies
HPA	Cluster Autoscaler	Pod vs Node scaling logic

✅ Phase 10 — Final Checklist
Feature	Local Validation	AWS Parity
Pods scale via HPA	✅ kubectl top pods	✅ CloudWatch metrics scale nodes
HTTPS ingress works	✅ mkcert + Traefik	✅ ACM + ALB
PVCs auto-bind	✅ OpenEBS	✅ EBS CSI
Logs visible in Grafana	✅ Loki	✅ CloudWatch
GitOps deploys	✅ ArgoCD	✅ CodePipeline / ArgoCD

🧭 Phase 11 — Runtime-Config Next.js Proxy (FE Layer)
Layer	Local	Cloud
API Proxy	Next Route Handler (/api/[...path]/route.ts)	Same image reused; env from Deployment
Env Source	.env.local	API_URL in K8s Deployment
Runtime Change	No rebuild	Hot reload via kubectl rollout restart

✅ End Goal
Be EKS-ready — able to deploy, secure, scale, observe, and automate workloads in AWS EKS with the same confidence you have locally.

🪶 Notes
Keep this roadmap file versioned in Git (EKS-Local-to-Cloud-Roadmap.md).

Annotate each phase with your cluster screenshots, YAMLs, and learnings.

You’ll fully understand:

Kubernetes networking and ingress mapping to AWS

RBAC and IAM parity

Storage, TLS, and secrets flow

GitOps, metrics, and cost control

Local → EKS migration with no surprises

📘 Srotas Infra Playbook • v1.0
Author: Sandeep “Xsm” Maurya

yaml
Copy code

---

Would you like me to include your **setup.sh** and **teardown.sh** (Phase 0) inside the same markdown file as appendix sections (for GitHub README style)?




