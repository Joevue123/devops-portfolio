# 45 — vCluster Multi-Tenancy

Each team gets a full virtual Kubernetes cluster (vCluster) running inside a namespace on the shared host cluster. Teams have cluster-admin inside their vCluster, can install CRDs and operators, and are completely isolated — without the cost of a dedicated cluster per team.

## Architecture

```
Host Cluster (EKS — platform team manages)
├── Namespace: team-payments
│   └── vCluster: payments-dev     ← team gets kubeconfig for this
│       ├── control plane (k3s)    ← runs inside a StatefulSet
│       ├── syncer                 ← syncs Pods, Services to host ns
│       └── "cluster-admin" for payments team inside this vCluster
│
├── Namespace: team-checkout
│   └── vCluster: checkout-dev
│       └── (same pattern)
│
├── Namespace: team-notifications
│   └── vCluster: notifications-staging
│
└── Platform namespace (host)
    ├── Monitoring (Prometheus, Grafana) — sees all namespaces
    ├── Falco DaemonSet — host-level security
    └── Network policies — enforce isolation between team namespaces

Isolation Model:
- Pods from different vClusters land in different host namespaces
- NetworkPolicy: deny cross-namespace traffic by default
- ResourceQuota on host namespace limits total vCluster resources
- Host cluster nodes are shared but namespaced
```

## Problem Statement

One cluster per team costs $150-300/month per cluster in control plane fees alone. Namespace-based multi-tenancy gives teams too little isolation — they can't install CRDs or operators. vCluster gives team isolation at < 5% overhead versus dedicated clusters.

## Key Files

```
k8s/vcluster-values.yaml         — vCluster Helm values (k3s, syncer config)
k8s/tenant-namespace.yaml        — host namespace + ResourceQuota + NetworkPolicy
k8s/vcluster-deployment.yaml     — vCluster Helm release via ArgoCD
scripts/provision-tenant.sh      — self-service: create namespace + vCluster
scripts/get-kubeconfig.sh        — retrieve kubeconfig for a team's vCluster
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| vCluster over namespace isolation | Teams can install CRDs, operators, custom RBAC — impossible in shared namespaces |
| k3s as virtual control plane | Lightweight; single StatefulSet; < 500MB memory overhead |
| Syncer for Pod execution | Pods run on host nodes — no nested virtualization penalty |
| ResourceQuota on host namespace | Cap each team's resource consumption at the host level |
| ArgoCD manages vCluster lifecycle | vCluster itself is a GitOps resource; teams can't modify host |

## Usage

```bash
# Provision a new team vCluster (platform team runs this)
./scripts/provision-tenant.sh \
  --team payments \
  --env dev \
  --cpu-limit 16 \
  --memory-limit 32Gi \
  --gpu-limit 0

# Get kubeconfig for the team
./scripts/get-kubeconfig.sh payments dev > ~/.kube/payments-dev.kubeconfig

# Team uses their vCluster as a normal cluster
export KUBECONFIG=~/.kube/payments-dev.kubeconfig
kubectl get nodes    # shows virtual node(s)
kubectl create ns my-app
kubectl apply -f my-operator.yaml    # installs CRD — isolated to their vCluster

# Platform team monitors all vClusters
kubectl get pods -A | grep vcluster
```

## Self-Service Portal (Backstage Integration)

Teams request a vCluster via Backstage scaffolder template:
1. Fill in: team name, environment, resource requirements
2. Template creates: namespace, ResourceQuota, NetworkPolicy, vCluster HelmRelease
3. ArgoCD syncs → vCluster is ready in ~2 minutes
4. Kubeconfig delivered via Vault secret

## Production Considerations

- **vCluster HA** — production vClusters use embedded etcd with 3 replicas
- **Node affinity** — pin vCluster control plane to dedicated nodes for predictable latency
- **Backup** — Velero backs up host namespaces (includes vCluster etcd state)
- **Upgrade strategy** — upgrade vCluster version independently per team; no coordinated freeze

## Success Metrics

- Cost per team environment: < $50/month (vs $200+ for dedicated EKS)
- vCluster provisioning time: < 3 minutes end-to-end
- Isolation verified: teams cannot list pods in other teams' host namespaces
