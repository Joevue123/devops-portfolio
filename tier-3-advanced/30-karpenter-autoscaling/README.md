# 30 — Karpenter Just-in-Time Node Autoscaling

**Tier:** Advanced | **Skills:** Karpenter, EC2 Fleet, spot instances, bin packing, node lifecycle

## Problem Statement

Cluster Autoscaler scales node groups — it's slow (2-3 min), wastes capacity through over-provisioning, and can't pick the right instance type per workload. Karpenter watches unschedulable pods directly and provisions the *exact* EC2 instance type needed in 30-60 seconds.

## Architecture

```
Workload demand increases (HPA adds pods / new deployment)
                │
                ▼
┌────────────────────────────────────────────────────────────────┐
│  Kubernetes Scheduler                                          │
│    Pod is Pending (no node has enough cpu/mem)                 │
└──────────────────────────────────┬─────────────────────────────┘
                                   │ Pending pod event
                                   ▼
┌────────────────────────────────────────────────────────────────┐
│  Karpenter (watching for unschedulable pods)                   │
│                                                                │
│  1. Reads pod's resource requests + node selectors             │
│  2. Evaluates NodePool constraints:                            │
│       instanceCategory: [c, m, r]                             │
│       capacity-type: [spot, on-demand]                         │
│       arch: [amd64, arm64]                                     │
│  3. Calls EC2 Fleet API — picks cheapest instance that fits    │
│     (bin-packing: place as many pods as possible per node)     │
│  4. Node joins cluster in ~30 seconds                          │
│  5. Pod scheduled, Running                                     │
│                                                                │
│  Consolidation (cost optimization):                            │
│    Karpenter continuously evaluates if nodes can be            │
│    consolidated — moves pods, terminates underutilized nodes   │
│    Runs every few minutes, saves 20-40% on compute             │
└────────────────────────────────────────────────────────────────┘

NodePool: general-purpose
  - Spot c6g, m6g, r6g (arm64, cheaper)    ← for stateless workloads
  - On-demand fallback if spot unavailable

NodePool: gpu
  - On-demand g4dn.xlarge                  ← for ML inference pods

NodePool: database
  - On-demand r6i.large, r6i.xlarge        ← memory-optimized, no spot
  - taint: dedicated=database:NoSchedule   ← only DB pods land here
```

## Usage

```bash
# Install Karpenter (via Helm, with IRSA)
helm registry login public.ecr.aws
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version 1.0.0 \
  --namespace kube-system \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.interruptionQueue=${QUEUE_NAME} \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi

# Apply NodePool and EC2NodeClass
kubectl apply -f k8s/

# Watch Karpenter provision nodes
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

# Simulate scaling
kubectl scale deployment api --replicas=50 -n production
kubectl get nodes -w   # watch new nodes appear in ~30s

# Check Karpenter decisions
kubectl get nodeclaims -w
```

## Key Decisions

- **Spot with on-demand fallback** — `karpenter.sh/capacity-type: spot` first; falls back to on-demand automatically
- **Multiple instance families** — `c6g,m6g,r6g` gives EC2 Fleet flexibility to find available capacity
- **`consolidationPolicy: WhenUnderutilized`** — aggressively consolidates to minimize idle nodes
- **Interruption handling via SQS** — Karpenter drains spot nodes before AWS reclaims them (2-min warning)

## Production Considerations

- Set `budgets` in NodePool to limit how many nodes Karpenter can disrupt at once during consolidation
- Use `topologySpreadConstraints` on critical Deployments so consolidation can't put all pods on one node
- Tag nodes with team/cost-center for showback: `karpenter.k8s.aws/nodeclaim` → resource tag
- Monitor `karpenter_nodes_total` and `karpenter_nodeclaims_disrupted_total` in Prometheus

## Metrics for Success

- Scale-out latency: pending pod → running < 60 seconds
- Spot usage: > 70% of total cluster node-hours
- Consolidation saves: 25-40% reduction in node count during low-traffic periods
