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

## Tier 3 — Advanced *(coming soon)*

Projects 21–30: Multi-stage canary deployments, chaos engineering with Litmus, Tekton pipelines, OPA policy enforcement.

## Tier 4 — Expert *(coming soon)*

Projects 31–40: Crossplane platform engineering, multi-cluster federation, FinOps dashboards, custom K8s operators.

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
