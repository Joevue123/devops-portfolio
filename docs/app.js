'use strict';

const GITHUB_BASE = 'https://github.com/joevue123/devops-portfolio/tree/main';

const PROJECTS = [
  {
    id: '01',
    title: 'Linux System Health Monitor',
    tier: 'tier-1',
    icon: '🖥️',
    summary: 'Dependency-free Bash script monitoring CPU, memory, disk, and load — with configurable thresholds and Slack/email alerting.',
    problem: 'Ops teams need early warning on resource exhaustion before services degrade.',
    skills: ['bash', 'cron', 'linux', 'alerting'],
    files: [
      'monitor.sh          — main monitoring script',
      'config.env.example  — threshold and alerting config',
    ],
    decisions: [
      'Pure Bash — works on any Linux host, zero dependencies',
      'Configurable thresholds via env file — no script edits needed',
      'Exit code 1 on alert — integrates with cron and monitoring systems',
    ],
    path: 'tier-1-foundational/01-linux-system-monitor',
  },
  {
    id: '02',
    title: 'Git Workflow Automation',
    tier: 'tier-1',
    icon: '🪝',
    summary: 'Pre-commit hooks and commit-msg validation enforcing Conventional Commits, secret scanning, branch naming policies, and 7 code quality checks.',
    problem: 'Teams waste review cycles on formatting issues and accidentally commit secrets.',
    skills: ['git', 'bash', 'pre-commit', 'security'],
    files: [
      '.pre-commit-config.yaml  — 7 hooks including detect-secrets',
      'hooks/commit-msg         — Conventional Commits enforcer',
      'hooks/pre-push           — branch naming policy',
      'install-hooks.sh         — one-command install into any repo',
    ],
    decisions: [
      'pre-commit framework over raw hooks — versioned and shareable',
      'detect-secrets runs first — cheapest blocker, stops secrets before CI',
      'Conventional Commits — enables automatic changelog + semver bumping',
    ],
    path: 'tier-1-foundational/02-git-workflow-automation',
  },
  {
    id: '03',
    title: 'Docker Multi-Stage Build',
    tier: 'tier-1',
    icon: '🐳',
    summary: 'Four-stage Dockerfile producing a 35MB distroless production image from a 1.2GB naive baseline — 97% smaller, no shell, non-root.',
    problem: 'Naive Docker images bloat to 1GB+ and expose unnecessary attack surface.',
    skills: ['docker', 'typescript', 'security', 'optimization'],
    files: [
      'Dockerfile     — 4 stages: deps, builder, test, production',
      '.dockerignore  — excludes node_modules, test files, git history',
      'src/index.ts   — minimal Node.js HTTP server',
    ],
    decisions: [
      'Distroless base — no shell means attackers cannot exec into the container',
      'Separate test stage — test tooling never enters production image',
      'Non-root user (uid 65532) — prevents privilege escalation',
    ],
    path: 'tier-1-foundational/03-docker-multistage-build',
  },
  {
    id: '04',
    title: 'Docker Compose Full Stack',
    tier: 'tier-1',
    icon: '📦',
    summary: 'Production-style Compose stack: Nginx reverse proxy + Node.js API + PostgreSQL + Redis, with isolated networks, health checks, and resource limits.',
    problem: 'Inconsistent local environments cause "works on my machine" failures.',
    skills: ['docker', 'docker-compose', 'nginx', 'postgresql', 'redis'],
    files: [
      'docker-compose.yml          — full stack with healthchecks',
      'nginx/conf.d/app.conf       — proxy, caching, rate limits',
      '.env.example                — environment variable template',
    ],
    decisions: [
      'Two isolated networks — frontend/backend separation; DB unreachable from Nginx',
      'Health check conditions on depends_on — API waits for DB to be truly ready',
      'Named volumes not bind mounts — portable across dev machines and CI',
    ],
    path: 'tier-1-foundational/04-docker-compose-stack',
  },
  {
    id: '05',
    title: 'GitHub Actions CI Pipeline',
    tier: 'tier-1',
    icon: '⚙️',
    summary: 'Full CI pipeline: lint → matrix tests across Node 18/20/22 → Trivy + Gitleaks security scan → OIDC push to ECR → staging deploy with Slack notify.',
    problem: 'A CI pipeline that just runs tests misses security, multi-version regressions, and safe cloud auth.',
    skills: ['github-actions', 'ci-cd', 'docker', 'aws', 'security'],
    files: [
      '.github/workflows/ci.yml  — complete 6-job pipeline',
    ],
    decisions: [
      'OIDC for AWS auth — no long-lived credentials stored in GitHub Secrets',
      'Matrix builds across Node 18/20/22 — catch version regressions early',
      'Lint runs first — cheapest check gates all others',
      'Multi-arch build (amd64 + arm64) — ARM cost savings on AWS Graviton',
    ],
    path: 'tier-1-foundational/05-github-actions-ci',
  },
  {
    id: '06',
    title: 'Terraform AWS Infrastructure',
    tier: 'tier-1',
    icon: '🏗️',
    summary: 'Three-tier AWS architecture in Terraform: VPC with NAT HA, Auto Scaling Group + ALB, RDS Multi-AZ, ElastiCache. Remote S3 state with DynamoDB locking.',
    problem: 'Console-clicked infrastructure is impossible to reproduce, audit, or version control.',
    skills: ['terraform', 'aws', 'vpc', 'iac'],
    files: [
      'main.tf              — root module wiring all components',
      'variables.tf         — all inputs with validation',
      'modules/vpc/main.tf  — VPC, subnets, IGW, NAT, route tables',
      'envs/staging.tfvars  — staging environment values',
      'envs/production.tfvars',
    ],
    decisions: [
      'Remote state in S3 + DynamoDB locking — safe for team use',
      'Workspaces for environments — same code, different tfvars',
      'NAT Gateway per AZ — prevents single-AZ network failure',
      'RDS Multi-AZ — automatic failover, no manual intervention',
    ],
    path: 'tier-1-foundational/06-terraform-aws-infra',
  },
  {
    id: '07',
    title: 'Nginx Reverse Proxy',
    tier: 'tier-1',
    icon: '🔀',
    summary: 'Production Nginx config with weighted upstream load balancing, TLS termination, rate limiting, proxy caching, and structured JSON access logs.',
    problem: 'Directly exposing app servers is insecure and unscalable.',
    skills: ['nginx', 'ssl', 'load-balancing', 'caching'],
    files: [
      'nginx/nginx.conf              — worker, events, rate limit zones',
      'nginx/conf.d/upstream.conf    — weighted round-robin pool',
      'docker-compose.yml            — full local stack for testing',
      'scripts/gen-self-signed-cert.sh',
    ],
    decisions: [
      'Separate rate limit zones per route — API and login limited more strictly',
      'keepalive 32 in upstream — connection pooling reduces TCP overhead',
      'JSON access logs — structured for direct ingestion into ELK/Loki',
      'proxy_cache_use_stale — serves stale content during upstream errors',
    ],
    path: 'tier-1-foundational/07-nginx-reverse-proxy',
  },
  {
    id: '08',
    title: 'ELK Log Aggregation',
    tier: 'tier-1',
    icon: '📊',
    summary: 'Complete ELK stack: Filebeat ships logs → Logstash parses with grok/geoip/useragent → Elasticsearch with ILM tiering → Kibana dashboards.',
    problem: 'Logs scattered across dozens of servers are impossible to correlate or search.',
    skills: ['elasticsearch', 'logstash', 'kibana', 'docker'],
    files: [
      'docker-compose.yml                — 5-service stack with log generator',
      'logstash/pipeline/main.conf        — grok, geoip, useragent, date parsing',
      'filebeat/filebeat.yml              — ships nginx, app, and Docker logs',
      'elasticsearch/ilm-policy.json      — hot/warm/delete tiering',
    ],
    decisions: [
      'ILM policy — automatic data tiering prevents disk exhaustion',
      'Filebeat over Logstash agent on source hosts — lightweight on servers',
      'Drop /health check logs — removes noise before it enters the pipeline',
    ],
    path: 'tier-1-foundational/08-elk-log-aggregation',
  },
  {
    id: '09',
    title: 'Ansible Server Hardening',
    tier: 'tier-1',
    icon: '🔒',
    summary: 'Idempotent Ansible playbooks applying CIS Level 1 benchmarks: SSH hardening, UFW firewall, kernel sysctl params, and auditd — across a multi-role fleet.',
    problem: 'Manually configured servers drift from their intended state and fail audits.',
    skills: ['ansible', 'linux', 'security', 'cis'],
    files: [
      'site.yml                              — master playbook',
      'roles/security/tasks/ssh.yml          — disable root, password auth',
      'roles/security/tasks/firewall.yml     — UFW rules per host group',
      'roles/security/tasks/sysctl.yml       — 10 CIS kernel params',
      'inventories/production/hosts.yml',
    ],
    decisions: [
      'Ansible Vault for secrets — never plaintext passwords in inventory',
      '--check --diff before every production run — review before applying',
      'Handlers for restarts — services only restart if config actually changed',
      'Tags on every task — allows surgical targeting without full playbook',
    ],
    path: 'tier-1-foundational/09-ansible-server-hardening',
  },
  {
    id: '10',
    title: 'Kubernetes App Deployment',
    tier: 'tier-1',
    icon: '☸️',
    summary: 'Full K8s deployment with Deployment (zero-downtime rolling), HPA, Ingress, PodDisruptionBudget, NetworkPolicy, and Kustomize overlays for staging/production.',
    problem: 'A bare Deployment and Service is not production-ready Kubernetes.',
    skills: ['kubernetes', 'kustomize', 'helm', 'hpa'],
    files: [
      'k8s/base/deployment.yaml     — readiness/liveness/startup probes, anti-affinity',
      'k8s/base/hpa.yaml            — CPU + memory autoscaling with scale-down cool-down',
      'k8s/base/pdb.yaml            — minAvailable: 2 during node drains',
      'k8s/base/networkpolicy.yaml  — ingress-only traffic to pods',
      'k8s/overlays/staging/        — 1 replica override for staging',
    ],
    decisions: [
      'maxUnavailable: 0 — zero-downtime deployments always maintain full capacity',
      'Startup probe separate from liveness — prevents premature kill during slow boot',
      'PodDisruptionBudget — ensures 2 pods stay up during node drain/upgrades',
      'Kustomize overlays — same base manifests for all environments',
    ],
    path: 'tier-1-foundational/10-kubernetes-app-deployment',
  },

  // ── Tier 3: Advanced ─────────────────────────────────────────────
  {
    id: '21',
    title: 'Automated Canary with Flagger',
    tier: 'tier-3',
    icon: '🐤',
    summary: 'Flagger automates progressive delivery: shifts 10% traffic per minute, gates on Prometheus error rate + p99 latency, rolls back instantly on regression — zero human approval.',
    problem: 'Manual canary deployments require humans watching dashboards at deploy time.',
    skills: ['flagger', 'kubernetes', 'prometheus', 'canary'],
    files: [
      'k8s/canary.yaml          — stepWeight, threshold, metric gates, webhooks',
      'k8s/metric-template.yaml — PromQL queries for success rate + latency',
    ],
    decisions: [
      'Automated metric gates — no human approval for standard deploys',
      'Load test webhook — canary gets real traffic during analysis window',
      'stepWeight: 10 with 1m interval — 10-minute full canary, fast enough to ship',
      'maxWeight: 50 — never send majority traffic to untested version',
    ],
    path: 'tier-3-advanced/21-canary-flagger',
  },
  {
    id: '22',
    title: 'Chaos Engineering with Litmus',
    tier: 'tier-3',
    icon: '💥',
    summary: 'Scheduled chaos experiments: pod-delete (50% of pods, every 30s), network-latency injection (200ms), node-drain. Steady-state hypothesis verified via HTTP + Prometheus probes.',
    problem: "You don't know if your system is resilient until it breaks in production.",
    skills: ['litmus', 'chaos-engineering', 'kubernetes', 'resilience'],
    files: [
      'experiments/pod-delete.yaml      — delete pods with HTTP liveness probe',
      'experiments/network-latency.yaml — 200ms injection + PromQL SLO probe',
      'workflows/game-day.yaml          — Argo Workflow for full game-day sequence',
    ],
    decisions: [
      'Steady-state hypothesis before chaos — define normal before breaking it',
      'podsAffectedPerc: 50 — blast radius control, never kill everything',
      'Continuous probes during experiment — catch degradation in real time',
      'Start in staging — validate experiments before targeting production',
    ],
    path: 'tier-3-advanced/22-chaos-engineering',
  },
  {
    id: '23',
    title: 'Tekton Cloud-Native CI/CD',
    tier: 'tier-3',
    icon: '🏭',
    summary: 'Kubernetes-native pipeline: GitHub webhook → EventListener → PipelineRun. Tasks: git-clone, npm test, kaniko build, Trivy scan, kubectl deploy. Each step is an isolated Pod.',
    problem: 'Jenkins and GitHub Actions run outside the cluster with no Kubernetes-native scaling.',
    skills: ['tekton', 'kubernetes', 'ci-cd', 'kaniko'],
    files: [
      'k8s/pipeline.yaml                — 6-task pipeline with finally block',
      'k8s/tasks/npm-lint-test.yaml     — lint + test as a reusable Task',
      'k8s/trigger/event-listener.yaml  — GitHub webhook → PipelineRun',
    ],
    decisions: [
      'Kaniko over Docker-in-Docker — builds images without privileged containers',
      'PVC workspace — Tasks share source code, no S3 artifact store needed',
      'finally tasks — Slack notify always runs, even on pipeline failure',
      'CEL interceptor — extracts 7-char git SHA as image tag at webhook time',
    ],
    path: 'tier-3-advanced/23-tekton-pipeline',
  },
  {
    id: '24',
    title: 'OPA Gatekeeper Policy Enforcement',
    tier: 'tier-3',
    icon: '⚖️',
    summary: 'Admission controller enforcing: resource limits required, no privileged containers, no latest tag, images from allowed registries only. Rego policies tested in CI before deployment.',
    problem: 'Kubernetes allows containers as root without resource limits by default.',
    skills: ['opa', 'gatekeeper', 'rego', 'security', 'kubernetes'],
    files: [
      'templates/require-resource-limits.yaml  — Rego: deny missing CPU/mem limits',
      'templates/allowed-registries.yaml       — Rego: parametrized registry allowlist',
      'constraints/production-constraints.yaml — enforcement: deny on production ns',
    ],
    decisions: [
      'Start in dryrun mode — audit violations without breaking existing workloads',
      'Exempt kube-system — system components must never be policy-blocked',
      'Rego unit tests in CI — opa test catches policy regressions before apply',
      'Deny messages explain exactly what to change, not just that it failed',
    ],
    path: 'tier-3-advanced/24-opa-gatekeeper',
  },
  {
    id: '25',
    title: 'eBPF Observability with Cilium',
    tier: 'tier-3',
    icon: '🔬',
    summary: 'Cilium replaces kube-proxy entirely. Hubble provides L7 HTTP flow visibility (method, path, status) per pod pair with zero sidecars. L7-aware NetworkPolicy: allow GET /api/* only.',
    problem: 'Traditional observability adds sidecar overhead; iptables breaks down at scale.',
    skills: ['ebpf', 'cilium', 'kubernetes', 'networking', 'security'],
    files: [
      'k8s/network-policy-l7.yaml  — allow GET /api/* from frontend only',
      'k8s/cilium-config.yaml      — kube-proxy replacement, WireGuard, Hubble',
    ],
    decisions: [
      'kubeProxyReplacement: true — removes iptables, eBPF is faster at scale',
      'Identity-based policy (labels not IPs) — survives pod restarts and IP churn',
      'L7 HTTP policy without sidecars — enforce REST method rules in kernel',
      'WireGuard encryption — node-to-node traffic encrypted without certificates',
    ],
    path: 'tier-3-advanced/25-ebpf-cilium',
  },
  {
    id: '26',
    title: 'Blue/Green Deployment',
    tier: 'tier-3',
    icon: '🔵🟢',
    summary: 'Both versions live simultaneously. Switch is a single Service selector patch (< 1 second). Script deploys to inactive slot, smoke tests it, switches, monitors error rate, auto-rolls back.',
    problem: 'Rolling updates take minutes and partial rollback under load is complex.',
    skills: ['kubernetes', 'deployment-strategy', 'bash', 'zero-downtime'],
    files: [
      'k8s/deployments.yaml   — api-blue and api-green Deployments + shared Service',
      'scripts/switch.sh      — deploy → smoke test → switch → monitor → auto-rollback',
    ],
    decisions: [
      'Both slots at full replicas — instant switch, no scale-up lag under load',
      'Smoke test pod exec before switch — validate before any user traffic hits new version',
      'Auto-rollback on error rate > 1% — no manual intervention needed',
      'Feature flags for DB migrations — backward-compatible schema before switch',
    ],
    path: 'tier-3-advanced/26-blue-green-deployment',
  },
  {
    id: '27',
    title: 'Crossplane Infrastructure Composition',
    tier: 'tier-3',
    icon: '🔧',
    summary: 'Platform team defines XAppDatabase CRD. Developer kubectl applies size:small + team:payments. Crossplane provisions RDS, subnet group, security group and writes connection details to a Secret.',
    problem: 'Developers needing databases should not need Terraform or AWS console access.',
    skills: ['crossplane', 'platform-engineering', 'aws', 'kubernetes'],
    files: [
      'xrds/app-database-xrd.yaml             — CompositeResourceDefinition (API schema)',
      'compositions/app-database-composition.yaml — maps XRD fields to RDS resources',
      'claims/app-database-claim.yaml          — developer self-service example',
    ],
    decisions: [
      'XRD abstracts cloud details — dev says size:small, Crossplane picks db.t3.micro',
      'Composition patches with transforms — size enum → instance class mapping',
      'Connection Secret auto-written — app consumes consistent Secret shape',
      'deletionProtection: true in base — Composition prevents accidental DB deletion',
    ],
    path: 'tier-3-advanced/27-crossplane-infra',
  },
  {
    id: '28',
    title: 'Velero Backup & Disaster Recovery',
    tier: 'tier-3',
    icon: '💾',
    summary: 'Daily full backup + hourly namespace backup to S3. Pre-backup PostgreSQL CHECKPOINT hook. Monthly DR drill script restores to isolated namespace, hits health endpoint, verifies RTO.',
    problem: 'An untested backup is not a backup — most teams discover gaps during an actual incident.',
    skills: ['velero', 'backup', 'disaster-recovery', 'aws'],
    files: [
      'schedules/backup-schedules.yaml  — daily full + hourly production schedules',
      'scripts/dr-drill.sh              — restore to dr-test namespace and verify',
    ],
    decisions: [
      'CSI snapshots over fs-backup — native EBS snapshots are faster and cheaper',
      'Pre-backup CHECKPOINT hook — prevents PostgreSQL data corruption in snapshots',
      'Cross-region S3 replication — region outage does not take down backups',
      'Restore to separate namespace — test in production cluster without risk',
    ],
    path: 'tier-3-advanced/28-velero-backup',
  },
  {
    id: '29',
    title: 'External Secrets Operator',
    tier: 'tier-3',
    icon: '🔑',
    summary: 'ClusterSecretStore connects to AWS Secrets Manager and Vault. ExternalSecrets sync on 1h schedule, auto-rotate when source changes. Stakater Reloader restarts pods on Secret update.',
    problem: 'Vault sidecars work per-pod but cluster-wide secrets need a different pattern.',
    skills: ['external-secrets', 'vault', 'aws', 'kubernetes', 'security'],
    files: [
      'k8s/secret-store.yaml      — AWS SM + Vault ClusterSecretStores with IRSA',
      'k8s/external-secrets.yaml  — sync API creds + dynamic Vault DB creds',
    ],
    decisions: [
      'ClusterSecretStore — one store definition used across all namespaces',
      'refreshInterval: 55m for Vault — shorter than 1h TTL, prevents expiry gap',
      'deletionPolicy: Retain — ESO deletion does not take down production secrets',
      'Combine with Reloader — pods restart automatically when Secret rotates',
    ],
    path: 'tier-3-advanced/29-external-secrets',
  },
  {
    id: '30',
    title: 'Karpenter Node Autoscaling',
    tier: 'tier-3',
    icon: '🚀',
    summary: 'Provisions the exact EC2 instance type needed in 30-60s. Spot-first with on-demand fallback. Dedicated database NodePool with NoSchedule taint. Consolidation cuts idle node costs 25-40%.',
    problem: 'Cluster Autoscaler is slow (2-3 min), over-provisions, and can\'t pick the right instance type.',
    skills: ['karpenter', 'aws', 'kubernetes', 'autoscaling', 'cost'],
    files: [
      'k8s/node-pool.yaml       — general (spot+OD) and database (OD-only) NodePools',
      'k8s/ec2-node-class.yaml  — AMI, subnet, security group, EBS config',
    ],
    decisions: [
      'Spot with on-demand fallback — EC2 Fleet picks cheapest available capacity',
      'Multiple instance families (c,m,r) — flexibility to find available spot',
      'consolidationPolicy: WhenUnderutilized — aggressively removes idle nodes',
      'budgets: 10% — Karpenter disrupts at most 10% of nodes at once',
    ],
    path: 'tier-3-advanced/30-karpenter-autoscaling',
  },

  // ── Tier 2: Intermediate ──────────────────────────────────────────
  {
    id: '11',
    title: 'Helm Chart — Microservice Packaging',
    tier: 'tier-2',
    icon: '⛵',
    summary: 'Production-ready Helm chart with conditional HPA/Ingress, _helpers.tpl labels, checksum-based rollouts, and separate prod values — deployable with helm upgrade --atomic.',
    problem: 'Copying raw YAML between environments causes drift and deployment errors.',
    skills: ['helm', 'kubernetes', 'templating'],
    files: [
      'myapp/Chart.yaml             — chart metadata and versioning',
      'myapp/values.yaml            — safe defaults for dev',
      'myapp/values-prod.yaml       — production overrides',
      'myapp/templates/_helpers.tpl — reusable name and label macros',
      'myapp/templates/deployment.yaml',
      'myapp/templates/hpa.yaml     — conditionally rendered',
    ],
    decisions: [
      '--atomic on upgrade — auto-rollback if any resource fails healthy',
      'checksum/config annotation — rolling restart when ConfigMap changes',
      'Conditional HPA/Ingress — disabled in dev with hpa.enabled: false',
      'No secrets in values.yaml — injected at deploy time via externalSecretName',
    ],
    path: 'tier-2-intermediate/11-helm-chart',
  },
  {
    id: '12',
    title: 'ArgoCD GitOps Pipeline',
    tier: 'tier-2',
    icon: '🔄',
    summary: 'App of Apps pattern: one root Application deploys all others. selfHeal reverts manual kubectl changes, AppProject enforces RBAC on repos and namespaces.',
    problem: 'Imperative kubectl apply leaves no audit trail and diverges from Git.',
    skills: ['argocd', 'gitops', 'kubernetes', 'ci-cd'],
    files: [
      'argocd/apps/root-app.yaml    — App of Apps entrypoint',
      'argocd/apps/api.yaml         — Helm-sourced application',
      'argocd/projects/portfolio.yaml — RBAC: allowed repos and namespaces',
      'scripts/bootstrap-argocd.sh',
    ],
    decisions: [
      'selfHeal: true — any manual kubectl change reverted within 3 minutes',
      'ignoreDifferences for replicas — HPA manages this, not ArgoCD',
      'AppProject RBAC — teams can only deploy to their own namespaces',
      'Sync waves — CRDs deploy before apps that depend on them',
    ],
    path: 'tier-2-intermediate/12-argocd-gitops',
  },
  {
    id: '13',
    title: 'Prometheus + Grafana Stack',
    tier: 'tier-2',
    icon: '📈',
    summary: 'Full observability: recording rules pre-compute SLO math, alert rules fire on symptoms (error rate, latency), AlertManager routes critical → PagerDuty, warning → Slack.',
    problem: "You can't fix what you can't see — scattered metrics mean slow MTTR.",
    skills: ['prometheus', 'grafana', 'alertmanager', 'docker'],
    files: [
      'prometheus/prometheus.yml          — scrape config',
      'prometheus/rules/api-alerts.yml    — recording + alert rules',
      'alertmanager/alertmanager.yml      — routing, inhibition, PagerDuty',
      'docker-compose.yml                 — full local stack',
    ],
    decisions: [
      'Alert on symptoms not causes — error rate > 1%, not CPU > 80%',
      'Recording rules for SLO math — pre-computed, dashboards load fast',
      'Inhibition rules — suppress downstream alerts when root cause fires',
      'Watchdog alert blackholed — avoids alert fatigue from healthcheck spam',
    ],
    path: 'tier-2-intermediate/13-prometheus-grafana',
  },
  {
    id: '14',
    title: 'Vault Secrets Management',
    tier: 'tier-2',
    icon: '🔐',
    summary: 'Dynamic DB credentials with 1h TTL (Vault creates unique PostgreSQL users per pod), static KV secrets, Kubernetes auth via ServiceAccount, agent sidecar injection.',
    problem: 'Shared DB passwords and base64 K8s Secrets are a security liability.',
    skills: ['vault', 'security', 'kubernetes', 'docker'],
    files: [
      'scripts/init-vault.sh           — enables KV, database, K8s auth',
      'vault/policies/api-policy.hcl   — least-privilege HCL policy',
      'k8s/vault-agent-sidecar.yaml    — annotation-driven secret injection',
      'docker-compose.yml',
    ],
    decisions: [
      'Dynamic DB creds — breach = revoke one user, not rotate shared password',
      'Agent sidecar — secrets on tmpfs volume, never stored in etcd',
      'Short TTLs (1h) — leaked credential is time-bounded',
      'Policies as code in Git — no manual vault policy write in production',
    ],
    path: 'tier-2-intermediate/14-vault-secrets',
  },
  {
    id: '15',
    title: 'Istio Service Mesh',
    tier: 'tier-2',
    icon: '🕸️',
    summary: 'mTLS STRICT mode across all pods, canary traffic split (90/10) via VirtualService weights, circuit breaker via outlierDetection, retry/timeout policies — zero app code changes.',
    problem: 'Microservices talk over plain HTTP with no auth, no retries, no visibility.',
    skills: ['istio', 'kubernetes', 'mtls', 'canary'],
    files: [
      'k8s/peer-authentication.yaml     — STRICT mTLS namespace-wide',
      'k8s/destination-rule.yaml        — circuit breaker + connection pool',
      'k8s/virtual-service-canary.yaml  — 90/10 weighted traffic split',
      'k8s/gateway.yaml                 — TLS ingress gateway',
    ],
    decisions: [
      'PeerAuthentication STRICT — zero-trust; pods without cert are rejected',
      'Canary via weights, not DNS — no TTL wait, instant rollback',
      'outlierDetection — ejects misbehaving pods from load balancing pool',
      'Header-based forced canary — specific testers always hit v2',
    ],
    path: 'tier-2-intermediate/15-istio-service-mesh',
  },
  {
    id: '16',
    title: 'KEDA Event-Driven Autoscaling',
    tier: 'tier-2',
    icon: '⚡',
    summary: 'Scale workers to zero on empty SQS queue, scale to 50 pods at 500 messages. Scale API on Prometheus RPS metric. IRSA auth — no stored AWS keys.',
    problem: 'CPU-based HPA is the wrong signal for queue workers and async workloads.',
    skills: ['keda', 'kubernetes', 'aws', 'autoscaling'],
    files: [
      'k8s/scaledobject-sqs.yaml        — SQS queue depth trigger, scale-to-zero',
      'k8s/scaledobject-http.yaml       — Prometheus RPS trigger',
      'k8s/triggerauthentication.yaml   — IRSA pod identity (no stored keys)',
    ],
    decisions: [
      'minReplicaCount: 0 — eliminates idle compute cost on empty queues',
      'cooldownPeriod: 300s — prevents thrashing on bursty workloads',
      'IRSA via TriggerAuthentication — no AWS credentials stored anywhere',
      'ScaledObject → HPA under the hood — Kubernetes-native, no lock-in',
    ],
    path: 'tier-2-intermediate/16-keda-autoscaling',
  },
  {
    id: '17',
    title: 'AWS Lambda Serverless API',
    tier: 'tier-2',
    icon: 'λ',
    summary: 'Full CRUD REST API: Python Lambda on arm64/Graviton + API Gateway v2 + DynamoDB on-demand, all Terraform-managed. X-Ray tracing, CloudWatch logs, IAM least-privilege.',
    problem: 'Not every workload needs a running server — pay-per-invocation eliminates idle cost.',
    skills: ['lambda', 'aws', 'terraform', 'python', 'serverless'],
    files: [
      'lambda/handler.py    — CRUD handler with DynamoDB (Python 3.12)',
      'main.tf              — Lambda, API Gateway v2, DynamoDB, IAM',
      'variables.tf',
      'outputs.tf           — API Gateway invoke URL',
    ],
    decisions: [
      'arm64 Graviton runtime — 20% cheaper, often faster for Python',
      'API Gateway v2 (HTTP API) — 70% cheaper than REST API',
      'On-demand DynamoDB — zero capacity planning, scales to any RPS',
      'Least-privilege IAM — Lambda can only DynamoDB:GetItem/PutItem/DeleteItem',
    ],
    path: 'tier-2-intermediate/17-aws-lambda-serverless',
  },
  {
    id: '18',
    title: 'Harbor Container Registry',
    tier: 'tier-2',
    icon: '⚓',
    summary: 'Self-hosted OCI registry with Trivy vulnerability scanning (block pull on CRITICAL CVE), project RBAC, robot accounts for CI, and replication rules to ECR.',
    problem: 'Docker Hub means public images, rate limits, and no control over pulls.',
    skills: ['harbor', 'docker', 'security', 'registry'],
    files: [
      'scripts/setup-harbor.sh         — generates certs, starts docker compose',
      'scripts/create-robot-account.sh — per-project CI bot accounts',
    ],
    decisions: [
      'Block pull on CRITICAL CVE — enforced at registry, not CI compliance',
      'Robot accounts for CI — scoped tokens, not shared admin credentials',
      'Replication to ECR — K8s clusters pull from ECR at deploy time',
      'Retention policy — auto-delete untagged images after 7 days',
    ],
    path: 'tier-2-intermediate/18-harbor-registry',
  },
  {
    id: '19',
    title: 'Cert-Manager TLS Automation',
    tier: 'tier-2',
    icon: '🔏',
    summary: 'Automatic Let\'s Encrypt wildcard certs via DNS-01/Route53. Renews 30 days before expiry. Staging issuer for testing, production issuer for live. Zero manual cert work.',
    problem: 'Manually renewing TLS certificates is toil that causes outages when forgotten.',
    skills: ['cert-manager', 'kubernetes', 'tls', 'aws'],
    files: [
      'k8s/cluster-issuer.yaml   — staging + production ClusterIssuers',
      'k8s/certificate.yaml      — wildcard cert, 90-day validity, renew at 30d',
      'scripts/verify-cert.sh    — check expiry and provisioning status',
    ],
    decisions: [
      'DNS-01 challenge — enables wildcard certs, works for internal services',
      'Staging issuer first — no rate limits, test full ACME flow safely',
      'ClusterIssuer not Issuer — one config works across all namespaces',
      'IRSA for Route53 — no AWS credentials stored in K8s Secrets',
    ],
    path: 'tier-2-intermediate/19-cert-manager-tls',
  },
  {
    id: '20',
    title: 'Fluent Bit K8s Log Pipeline',
    tier: 'tier-2',
    icon: '🪵',
    summary: 'DaemonSet on every node tails all container logs, enriches with K8s metadata (namespace/pod/labels), drops health check noise, ships to Loki with filesystem buffering.',
    problem: 'kubectl logs shows one pod and loses history — you need centralized, queryable logs.',
    skills: ['fluentbit', 'kubernetes', 'loki', 'observability'],
    files: [
      'k8s/configmap.yaml    — full Fluent Bit config (INPUT/FILTER/OUTPUT)',
      'k8s/daemonset.yaml    — hostPath mounts, resource limits, liveness probe',
    ],
    decisions: [
      'SQLite offset DB — survives restarts without re-sending old logs',
      'Mem_Buf_Limit — caps memory, applies backpressure rather than OOM kill',
      'Drop /health and /metrics logs — removes noise before pipeline ingestion',
      'Fluent Bit over Fluentd — 10x lower memory per node',
    ],
    path: 'tier-2-intermediate/20-fluentbit-k8s-logging',
  },
];

// ── Rendering ────────────────────────────────────────────────────────────────

function renderProjects(filter) {
  const grid = document.getElementById('projects-grid');
  grid.innerHTML = '';

  const filtered = filter === 'all'
    ? PROJECTS
    : PROJECTS.filter(p =>
        p.tier === filter ||
        p.skills.some(s => s.toLowerCase().includes(filter))
      );

  filtered.forEach(project => {
    const card = document.createElement('article');
    card.className = 'project-card';
    card.setAttribute('data-tier', project.tier);
    card.setAttribute('data-id', project.id);

    card.innerHTML = `
      <div class="project-card-header">
        <span class="project-number">#${project.id}</span>
        <span class="tier-badge ${project.tier}">Tier ${project.tier.split('-')[1]}</span>
      </div>
      <div style="display:flex;align-items:flex-start;gap:10px">
        <span class="project-icon">${project.icon}</span>
        <h3>${project.title}</h3>
      </div>
      <p>${project.summary}</p>
      <div class="project-skills">
        ${project.skills.map(s => `<span class="skill-tag">${s}</span>`).join('')}
      </div>
      <div class="project-card-footer">
        <span class="view-link">
          View details
          <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor">
            <path d="M1 8a.5.5 0 01.5-.5h11.793l-3.147-3.146a.5.5 0 01.708-.708l4 4a.5.5 0 010 .708l-4 4a.5.5 0 01-.708-.708L13.293 8.5H1.5A.5.5 0 011 8z"/>
          </svg>
        </span>
        <a href="${GITHUB_BASE}/${project.path}" target="_blank" rel="noopener"
           class="btn btn-outline" style="font-size:11px;padding:4px 10px"
           onclick="event.stopPropagation()">
          Source
        </a>
      </div>
    `;

    card.addEventListener('click', () => openModal(project));
    grid.appendChild(card);
  });

  // Show/hide section headings and coming-soon based on filter
  const comingSoon = document.getElementById('coming-soon');
  const tier1Heading = document.getElementById('tier-1-heading');
  const tier2Heading = document.getElementById('tier-2-heading');
  const tier3Heading = document.getElementById('tier-3-heading');
  const showAll = filter === 'all';
  comingSoon.style.display = showAll ? '' : 'none';
  tier1Heading.style.display = showAll ? '' : 'none';
  tier2Heading.style.display = showAll ? '' : 'none';
  tier3Heading.style.display = showAll ? '' : 'none';
}

// ── Modal ─────────────────────────────────────────────────────────────────────

function openModal(project) {
  const overlay = document.getElementById('modal-overlay');
  const content = document.getElementById('modal-content');

  content.innerHTML = `
    <div class="modal-header">
      <span class="modal-icon">${project.icon}</span>
      <div>
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px">
          <span class="tier-badge ${project.tier}">Tier ${project.tier.split('-')[1]}</span>
          <span style="font-family:var(--mono);font-size:11px;color:var(--text-dim)">#${project.id}</span>
        </div>
        <h2 class="modal-title">${project.title}</h2>
        <p class="modal-subtitle">${project.summary}</p>
      </div>
    </div>

    <div class="modal-section">
      <h4>Problem Statement</h4>
      <p>${project.problem}</p>
    </div>

    <div class="modal-section">
      <h4>Key Files</h4>
      <div class="modal-files">${project.files.join('\n')}</div>
    </div>

    <div class="modal-section">
      <h4>Engineering Decisions</h4>
      <ul style="padding-left:20px;font-size:14px;color:var(--text-muted);line-height:2">
        ${project.decisions.map(d => `<li>${d}</li>`).join('')}
      </ul>
    </div>

    <div class="modal-section">
      <h4>Skills</h4>
      <div class="modal-skills">
        ${project.skills.map(s => `<span class="skill-tag">${s}</span>`).join('')}
      </div>
    </div>

    <div class="modal-actions">
      <a href="${GITHUB_BASE}/${project.path}" target="_blank" rel="noopener" class="btn btn-primary">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/></svg>
        View on GitHub
      </a>
      <a href="${GITHUB_BASE}/${project.path}/README.md" target="_blank" rel="noopener" class="btn btn-outline">
        Read README
      </a>
    </div>
  `;

  overlay.classList.add('open');
  overlay.setAttribute('aria-hidden', 'false');
  document.body.style.overflow = 'hidden';
}

function closeModal() {
  const overlay = document.getElementById('modal-overlay');
  overlay.classList.remove('open');
  overlay.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
}

// ── Filters ──────────────────────────────────────────────────────────────────

document.querySelectorAll('.filter-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    renderProjects(btn.dataset.filter);
  });
});

document.getElementById('modal-close').addEventListener('click', closeModal);
document.getElementById('modal-overlay').addEventListener('click', e => {
  if (e.target === e.currentTarget) closeModal();
});
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeModal();
});

// ── Init ─────────────────────────────────────────────────────────────────────
renderProjects('all');
