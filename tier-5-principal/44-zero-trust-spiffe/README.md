# 44 — Zero-Trust with SPIFFE/SPIRE

Every workload gets a cryptographic identity (SVID X.509 certificate) from SPIRE. Services authenticate with short-lived certs instead of long-lived API keys. mTLS between all services — no network perimeter, no VPN, no service account tokens shared as secrets.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  SPIRE Server (StatefulSet, HA)                                      │
│  ├── Issues SVIDs (X.509 certs, 1-hour TTL, auto-renew)             │
│  ├── Validates node attestation (AWS IID attestor)                   │
│  └── Validates pod attestation (K8s SA + pod labels)                 │
│                                                                      │
│  SPIRE Agent (DaemonSet, one per node)                               │
│  ├── Attests node to SPIRE Server (AWS Instance Identity Document)   │
│  ├── Issues SVIDs to pods via Unix socket                            │
│  └── Workload API: /run/spire/sockets/agent.sock                     │
│                                                                      │
│  Workload Pod                                                        │
│  ├── SPIFFE Workload API client (reads SVID from socket)             │
│  ├── SVID: spiffe://cluster.example.com/ns/production/sa/api        │
│  ├── Rotates cert automatically every 55 minutes                     │
│  └── Presents cert in TLS handshake (mTLS to all services)          │
│                                                                      │
│  Zero-Trust Policy (Cilium CiliumNetworkPolicy):                     │
│  ├── Deny all by default                                             │
│  ├── Allow api → database (SPIFFE ID match, port 5432)               │
│  └── Allow ingress → api (SPIFFE ID match, port 8080)                │
└──────────────────────────────────────────────────────────────────────┘

Trust Domain: spiffe://cluster.example.com
Identity format: spiffe://cluster.example.com/ns/<namespace>/sa/<serviceaccount>
```

## Problem Statement

Kubernetes network policies and service accounts provide coarse isolation, but a stolen JWT token is valid until expiry. SPIFFE gives every workload a short-lived, cryptographically verifiable identity that's automatically rotated — no static credentials, no perimeter to defend.

## Key Files

```
k8s/spire-server.yaml         — SPIRE Server StatefulSet + RBAC
k8s/spire-agent.yaml          — SPIRE Agent DaemonSet
k8s/registration-entries.yaml — Workload registration (maps pod labels → SPIFFE IDs)
k8s/spiffe-csi-driver.yaml    — CSI driver to mount SVID as volume (no SDK needed)
scripts/verify-identity.sh    — Inspect a pod's current SVID
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| SPIRE over Vault PKI for workload identity | SPIRE is purpose-built for SPIFFE; push-model avoids polling |
| AWS IID node attestor | No bootstrap secret needed — uses AWS signed identity doc |
| 1-hour SVID TTL | Short enough to limit blast radius; auto-renewed at 55 min |
| SPIFFE CSI Driver | Apps get cert via volume mount — no SDK integration required |
| OPA + SPIFFE for authz | SPIFFE = who you are; OPA = what you're allowed to do |

## Usage

```bash
# Deploy SPIRE
kubectl apply -f k8s/spire-server.yaml
kubectl apply -f k8s/spire-agent.yaml
kubectl apply -f k8s/spiffe-csi-driver.yaml

# Register workloads
kubectl apply -f k8s/registration-entries.yaml

# Verify a pod has received its SVID
./scripts/verify-identity.sh production api

# Check SVID details in a running pod
kubectl exec -n production deploy/api -- \
  /opt/spire/bin/spire-agent api fetch x509 \
  -socketPath /run/spire/sockets/agent.sock

# Inspect certificate
kubectl exec -n production deploy/api -- \
  openssl x509 -in /run/spire/svid.pem -text -noout | grep -A2 "Subject Alternative Name"
# URI:spiffe://cluster.example.com/ns/production/sa/api
```

## Production Considerations

- **SPIRE Server HA** — bundled with embedded etcd or external DB for multi-replica
- **Nested SPIRE** — leaf SPIRE servers per cluster; root SPIRE issues trust to leaf servers
- **Federation** — `spiffe://cluster-a.example.com` trusts `spiffe://cluster-b.example.com` for cross-cluster calls
- **Istio integration** — Istio can use SPIRE as the CA instead of Citadel

## Success Metrics

- Zero long-lived credentials in Kubernetes Secrets
- SVID rotation: 100% of workloads renew without restart within 55-minute window
- mTLS coverage: 100% of east-west traffic encrypted and mutually authenticated
