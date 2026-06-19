# 28 — Velero Kubernetes Backup & Disaster Recovery

**Tier:** Advanced | **Skills:** Velero, backup strategy, DR testing, PV snapshots, restore

## Problem Statement

Etcd backup alone doesn't restore PersistentVolumes or let you migrate workloads between clusters. Velero backs up both K8s resources and volume data, with scheduled backups to S3 and tested restore procedures — because an untested backup is not a backup.

## Architecture

```
Kubernetes Cluster (production)
┌────────────────────────────────────────────────────────────────┐
│  Velero (in-cluster controller)                                │
│                                                                │
│  Scheduled Backups:                                            │
│    Daily full backup  (0 2 * * *)  → retention: 30 days        │
│    Hourly namespace backup         → retention: 7 days         │
│                                                                │
│  What gets backed up per namespace:                            │
│    K8s resources: Deployments, Services, ConfigMaps,           │
│                   Secrets, PVCs, Ingresses, CRDs               │
│    Volume data:   PV snapshots via CSI driver                  │
│                   (EBS → EBS snapshot, stored in S3)           │
│                                                                │
│  Hooks:                                                        │
│    pre-backup: quiesce app writes (flush DB buffers)           │
│    post-backup: resume writes                                  │
└──────────────────────────────────┬─────────────────────────────┘
                                   │
                                   ▼ S3 (server-side encrypted)
┌────────────────────────────────────────────────────────────────┐
│  S3 Bucket: velero-backups-prod                                │
│    backups/daily-2026-06-19/                                   │
│      ├── velero-backup.json.gz   (K8s resource manifests)      │
│      └── pv-snapshots/           (volume data)                 │
│                                                                │
│  Cross-region replication: us-east-1 → us-west-2              │
└──────────────────────────────────┬─────────────────────────────┘
                                   │ restore
                                   ▼
Kubernetes Cluster (DR / staging)
  velero restore create --from-backup daily-2026-06-19
```

## Usage

```bash
# Install Velero with AWS plugin
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket velero-backups-prod \
  --secret-file ./aws-credentials \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --use-node-agent   # for PVC backup without CSI snapshots

# Apply scheduled backup policies
kubectl apply -f schedules/

# Trigger manual backup
velero backup create pre-upgrade-backup --include-namespaces production

# List backups
velero backup get

# Restore to DR cluster
velero restore create --from-backup pre-upgrade-backup \
  --include-namespaces production \
  --namespace-mappings production:production-dr

# Verify restore
velero restore describe --details <restore-name>

# Disaster recovery drill (run monthly)
./scripts/dr-drill.sh
```

## Key Decisions

- **CSI snapshot provider** — native EBS snapshots are faster and cheaper than streaming volume data
- **Cross-region S3 replication** — a region outage doesn't take down your backups
- **Pre-backup hooks** — `pg_checkpoint` before snapping PostgreSQL PVs prevents corruption
- **Restore to separate namespace** — test restores in production cluster without affecting live traffic

## Production Considerations

- Run a full DR drill quarterly — restore to a test cluster, verify the app works, document the RTO
- Use `velero backup logs` to audit what was/wasn't captured; exclude ephemeral volumes
- Set `--default-volumes-to-fs-backup=false` and explicitly annotate which PVCs need backup
- Monitor backup success with `velero_backup_success_total` Prometheus metric — alert on 0

## Metrics for Success

- RTO (Recovery Time Objective) < 30 minutes verified by quarterly DR drill
- RPO (Recovery Point Objective) < 1 hour (hourly backups)
- 100% of backup success metrics green (Prometheus alert on any failure)
