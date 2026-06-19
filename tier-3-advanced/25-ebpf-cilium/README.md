# 25 — eBPF Network Observability with Cilium & Hubble

**Tier:** Advanced | **Skills:** eBPF, Cilium, Hubble, network policy, L7 visibility

## Problem Statement

Traditional network observability relies on sidecars or packet capture — both add overhead. eBPF programs run in the Linux kernel, giving deep network visibility at near-zero cost. Cilium replaces kube-proxy entirely and Hubble provides L7 flow visibility with identity-based security.

## Architecture

```
Linux Kernel (eBPF programs loaded by Cilium agent)
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  eBPF hooks at:                                                │
│    XDP (eXpress Data Path)  ← fastest, before sk_buff alloc   │
│    TC (Traffic Control)     ← ingress/egress per network iface │
│    kprobes/tracepoints      ← syscall-level visibility         │
│                                                                │
│  What Cilium sees per packet:                                  │
│    Source/Dest: pod identity (not just IP — identity is label) │
│    Protocol: TCP/UDP/HTTP/gRPC/Kafka (L7 parsing in kernel)   │
│    HTTP: method, path, status code, latency                    │
│    DNS: query, response, NXDOMAIN                              │
└───────────────────────────────┬────────────────────────────────┘
                                │ flow data
                                ▼
┌────────────────────────────────────────────────────────────────┐
│  Hubble (observability layer)                                  │
│                                                                │
│  Hubble UI  ─── service map with L7 flows (real-time)         │
│  Hubble CLI ─── flow inspection per pod/namespace              │
│  Prometheus ─── golden signals per service pair               │
│                                                                │
│  Example queries:                                              │
│    hubble observe --namespace production --protocol http       │
│    hubble observe --to-pod production/postgres --verdict DROPPED│
└────────────────────────────────────────────────────────────────┘

CiliumNetworkPolicy (L7-aware, Istio not required):
  allow: frontend → api:80 HTTP GET /api/*
  deny:  everything else
  (enforced in kernel — no iptables, no kube-proxy)
```

## Usage

```bash
# Install Cilium (replaces kube-proxy)
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set operator.replicas=1

# Verify Cilium status
cilium status --wait

# Enable Hubble
cilium hubble enable --ui

# Watch live L7 flows
hubble observe --namespace production --follow

# Watch dropped packets (policy denies)
hubble observe --verdict DROPPED --follow

# Apply L7-aware network policies
kubectl apply -f k8s/network-policies/

# Open Hubble UI (service map)
cilium hubble ui
```

## Key Decisions

- **`kubeProxyReplacement=true`** — removes iptables entirely; connection tracking in eBPF is faster and more scalable
- **Identity-based policy, not IP-based** — policies survive pod restarts and IP churn; based on K8s labels
- **L7 HTTP policy** — allow `GET /api/*` but deny `DELETE /api/*` without a WAF or sidecar
- **Hubble over Jaeger for network tracing** — kernel-level, zero app instrumentation required

## Production Considerations

- Cilium requires Linux kernel ≥ 5.4 (most managed K8s: EKS, GKE, AKS already meet this)
- Use `CiliumClusterwideNetworkPolicy` for cluster-wide defaults (deny all ingress by default)
- Monitor `cilium_drop_count_total` — sudden spikes indicate new policy violations
- Tetragon (Cilium's runtime security) extends eBPF to syscall-level enforcement (block `exec`, `open`)

## Metrics for Success

- Network policy enforcement latency < 1ms per packet (eBPF vs ~10ms iptables at scale)
- Zero kube-proxy pods (fully replaced by Cilium)
- L7 flow visibility for 100% of inter-service traffic with no sidecars
