# 32 — Cluster API (CAPI) Cluster Lifecycle Management

Use Cluster API to declaratively provision, upgrade, and delete Kubernetes clusters on AWS. A management cluster runs CAPI controllers; workload clusters are described as Kubernetes objects (`Cluster`, `MachineDeployment`, `AWSCluster`).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Management Cluster (EKS or kind bootstrap)                         │
│                                                                     │
│  CAPI Core Controller                                               │
│  CAPM3 / CAPA Controller (AWS provider)                             │
│  Bootstrap Provider (CABPK — kubeadm)                               │
│                                                                     │
│  Cluster CRs ──────────────────────────────────────────────────┐   │
│  AWSCluster CR (VPC, subnets, security groups)                 │   │
│  MachineDeployment CR (worker node groups)                     │   │
│  AWSMachineTemplate CR (instance type, AMI, IAM profile)       │   │
│  KubeadmConfigTemplate CR (cloud-init bootstrap)               │   │
└────────────────────────────────────────┬────────────────────────────┘
                                         │ provisions
                      ┌──────────────────┼──────────────────┐
                      ▼                  ▼                  ▼
               Cluster: staging   Cluster: prod     Cluster: prod-eu
               (3 control plane   (3 control plane  (3 control plane
                1 worker NG)       3 worker NGs)     2 worker NGs)
```

## Problem Statement

Manually provisioning clusters with eksctl or Terraform is ad-hoc — each cluster has its own state, version drift goes undetected, and upgrades are manual kubectl marathons. CAPI makes cluster lifecycle a GitOps-able Kubernetes object like any other.

## Key Files

```
clusters/staging-cluster.yaml        — Cluster + AWSCluster CRs
workers/machine-deployment.yaml      — MachineDeployment + AWSMachineTemplate
clusters/clusterclass-eks.yaml       — ClusterClass (topology-based clusters)
scripts/bootstrap.sh                 — Management cluster setup via clusterctl
scripts/upgrade-cluster.sh           — Zero-downtime control plane + worker upgrade
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| ClusterClass over raw CRs | One template definition, many cluster instances; enforce standards |
| AWS provider (CAPA) | Native EC2/EKS support, IAM role integration |
| Kubeadm bootstrap | Provider-agnostic, works with any Linux AMI |
| MachineHealthCheck | Auto-replace unhealthy nodes without human intervention |
| GitOps for cluster manifests | Cluster drift is caught by ArgoCD like any other resource |

## Usage

```bash
# 1. Install clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.7.0/clusterctl-linux-amd64 \
  -o /usr/local/bin/clusterctl && chmod +x /usr/local/bin/clusterctl

# 2. Bootstrap management cluster
./scripts/bootstrap.sh

# 3. Apply workload cluster
kubectl apply -f clusters/staging-cluster.yaml
kubectl apply -f workers/machine-deployment.yaml

# 4. Watch cluster come up
clusterctl describe cluster staging

# 5. Get kubeconfig
clusterctl get kubeconfig staging > ~/.kube/staging.kubeconfig

# 6. Upgrade control plane from 1.29 -> 1.30
./scripts/upgrade-cluster.sh staging 1.30.0
```

## Production Considerations

- **ClusterClass topology** — define once, stamp out many clusters with variables (region, instance type, version)
- **MachineHealthCheck** — remediate nodes stuck in NotReady for > 5 minutes automatically
- **Cluster autoscaler integration** — CAPI MachineDeployments scale out/in via Cluster Autoscaler annotations
- **etcd backup** — Velero + CAPI etcdrestore for control plane disaster recovery
- **Multi-region management cluster** — HA management cluster itself should survive AZ failures

## Success Metrics

- New cluster provisioned in < 15 minutes (vs hours manually)
- Cluster upgrades with zero control plane downtime
- < 5 minutes to detect and replace an unhealthy node
