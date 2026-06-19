# DevOps Portfolio

50 production-grade projects organized by difficulty, built to demonstrate real engineering depth across the full DevOps stack.

## Structure

| Tier | Level | Projects | Focus |
|------|-------|----------|-------|
| [Tier 1](./tier-1-foundational/) | Foundational | 01–10 | Linux, Docker, CI/CD basics, IaC intro |
| [Tier 2](./tier-2-intermediate/) | Intermediate | 11–20 | Kubernetes, observability, secrets, GitOps |
| [Tier 3](./tier-3-advanced/) | Advanced | 21–30 | Service mesh, chaos engineering, advanced pipelines |
| [Tier 4](./tier-4-expert/) | Expert | 31–40 | Platform engineering, multi-cluster, FinOps |
| [Tier 5](./tier-5-principal/) | Principal | 41–50 | Developer platforms, AI/ML infra, org-scale patterns |

## Tier 1 — Foundational

| # | Project | Skills |
|---|---------|--------|
| 01 | [Linux System Health Monitor](./tier-1-foundational/01-linux-system-monitor/) | Bash, cron, alerting |
| 02 | [Git Workflow Automation](./tier-1-foundational/02-git-workflow-automation/) | Git hooks, pre-commit, branch policies |
| 03 | [Docker Multi-Stage Build](./tier-1-foundational/03-docker-multistage-build/) | Docker, image optimization |
| 04 | [Docker Compose Full Stack](./tier-1-foundational/04-docker-compose-stack/) | Docker Compose, networking, volumes |
| 05 | [GitHub Actions CI Pipeline](./tier-1-foundational/05-github-actions-ci/) | GitHub Actions, matrix builds, caching |
| 06 | [Terraform AWS Infrastructure](./tier-1-foundational/06-terraform-aws-infra/) | Terraform, AWS VPC, remote state |
| 07 | [Nginx Reverse Proxy](./tier-1-foundational/07-nginx-reverse-proxy/) | Nginx, SSL termination, rate limiting |
| 08 | [ELK Log Aggregation](./tier-1-foundational/08-elk-log-aggregation/) | Elasticsearch, Logstash, Kibana |
| 09 | [Ansible Server Hardening](./tier-1-foundational/09-ansible-server-hardening/) | Ansible, roles, idempotent config |
| 10 | [Kubernetes App Deployment](./tier-1-foundational/10-kubernetes-app-deployment/) | K8s manifests, HPA, Ingress |

## Tier 2 — Intermediate

| # | Project | Skills |
|---|---------|--------|
| 11 | [Helm Chart — Microservice Packaging](./tier-2-intermediate/11-helm-chart/) | Helm, templating, values management |
| 12 | [ArgoCD GitOps Pipeline](./tier-2-intermediate/12-argocd-gitops/) | ArgoCD, App of Apps, selfHeal, RBAC |
| 13 | [Prometheus + Grafana Stack](./tier-2-intermediate/13-prometheus-grafana/) | Prometheus, Grafana, AlertManager, PromQL |
| 14 | [Vault Secrets Management](./tier-2-intermediate/14-vault-secrets/) | Vault, dynamic secrets, K8s auth, sidecar |
| 15 | [Istio Service Mesh](./tier-2-intermediate/15-istio-service-mesh/) | Istio, mTLS, canary, circuit breaker |
| 16 | [KEDA Event-Driven Autoscaling](./tier-2-intermediate/16-keda-autoscaling/) | KEDA, SQS, scale-to-zero, IRSA |
| 17 | [AWS Lambda Serverless API](./tier-2-intermediate/17-aws-lambda-serverless/) | Lambda, API Gateway, DynamoDB, Terraform |
| 18 | [Harbor Container Registry](./tier-2-intermediate/18-harbor-registry/) | Harbor, Trivy, RBAC, replication |
| 19 | [Cert-Manager TLS Automation](./tier-2-intermediate/19-cert-manager-tls/) | cert-manager, Let's Encrypt, DNS-01 |
| 20 | [Fluent Bit K8s Log Pipeline](./tier-2-intermediate/20-fluentbit-k8s-logging/) | Fluent Bit, DaemonSet, Loki |

## Tier 3 — Advanced

| # | Project | Skills |
|---|---------|--------|
| 21 | [Automated Canary with Flagger](./tier-3-advanced/21-canary-flagger/) | Flagger, progressive delivery, Prometheus gates |
| 22 | [Chaos Engineering with Litmus](./tier-3-advanced/22-chaos-engineering/) | LitmusChaos, steady-state hypothesis, Argo Workflow |
| 23 | [Tekton Cloud-Native CI/CD](./tier-3-advanced/23-tekton-pipeline/) | Tekton, Kaniko, EventListener, webhooks |
| 24 | [OPA Gatekeeper Policy](./tier-3-advanced/24-opa-gatekeeper/) | OPA, Gatekeeper, Rego, admission control |
| 25 | [eBPF Observability with Cilium](./tier-3-advanced/25-ebpf-cilium/) | eBPF, Cilium, Hubble, L7 policy, WireGuard |
| 26 | [Blue/Green Deployment](./tier-3-advanced/26-blue-green-deployment/) | Kubernetes, zero-downtime, auto-rollback |
| 27 | [Crossplane Infrastructure Composition](./tier-3-advanced/27-crossplane-infra/) | Crossplane, XRD, Composition, self-service |
| 28 | [Velero Backup & Disaster Recovery](./tier-3-advanced/28-velero-backup/) | Velero, CSI snapshots, S3, DR drills |
| 29 | [External Secrets Operator](./tier-3-advanced/29-external-secrets/) | ESO, AWS Secrets Manager, Vault, auto-rotation |
| 30 | [Karpenter Node Autoscaling](./tier-3-advanced/30-karpenter-autoscaling/) | Karpenter, spot, consolidation, NodePool |

## Tier 4 — Expert

| # | Project | Skills |
|---|---------|--------|
| 31 | [Custom Kubernetes Operator](./tier-4-expert/31-k8s-operator/) | Go, controller-runtime, CRD, finalizers |
| 32 | [Cluster API Lifecycle](./tier-4-expert/32-cluster-api/) | CAPI, CAPA, MachineHealthCheck, ClusterClass |
| 33 | [FinOps with Kubecost](./tier-4-expert/33-finops-kubecost/) | Kubecost, cost allocation, rightsizing |
| 34 | [OpenTelemetry Observability](./tier-4-expert/34-opentelemetry/) | OTel Collector, traces, metrics, logs, auto-instrumentation |
| 35 | [Backstage IDP](./tier-4-expert/35-backstage-idp/) | Backstage, software catalog, scaffolder templates |
| 36 | [Flux v2 GitOps](./tier-4-expert/36-flux-gitops/) | Flux v2, HelmRelease, image automation |
| 37 | [Falco Runtime Security](./tier-4-expert/37-falco-security/) | Falco, eBPF, custom rules, MITRE ATT&CK |
| 38 | [SLO/Error Budget Tracking](./tier-4-expert/38-slo-error-budget/) | Sloth, SLO, burn rate alerts, error budget policy |
| 39 | [RBAC Audit & Least-Privilege](./tier-4-expert/39-rbac-audit/) | RBAC, kube-bench, CIS benchmark, audit2rbac |
| 40 | [Multi-Region Active-Active](./tier-4-expert/40-multi-region/) | AWS, Route53, RDS Global, multi-region Terraform |

## Tier 5 — Principal *(coming soon)*

Projects 41–50: Internal developer platform, AI/ML training infra, org-scale IaC modules, golden path templates.

---

## Interview Talking Points

Each project README includes:
- **Problem statement** — what real-world pain this solves
- **Architecture diagram** — visual overview of components
- **Key decisions** — trade-offs made and why
- **Production considerations** — what you'd add before going live
- **Metrics** — how you'd measure success
