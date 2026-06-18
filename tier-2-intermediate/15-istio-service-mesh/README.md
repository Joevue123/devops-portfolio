# 15 — Istio Service Mesh

**Tier:** Intermediate | **Skills:** Istio, mTLS, traffic management, canary deploys, observability

## Problem Statement

Microservices talk to each other over plain HTTP with no auth, no retries, and no visibility into what fails where. Istio adds mTLS encryption, intelligent routing, automatic retries, circuit breaking, and distributed tracing — without changing a line of application code.

## Architecture

```
Istio Control Plane (istiod)
┌────────────────────────────────────────────────────────────┐
│  istiod                                                    │
│    ├── Pilot    ← pushes routing config to Envoy proxies   │
│    ├── Citadel  ← issues mTLS certificates (SPIFFE/X.509)  │
│    └── Galley   ← validates Istio config CRDs              │
└──────────────────────────────┬─────────────────────────────┘
                               │ xDS API (config distribution)
             ┌─────────────────┼──────────────────┐
             ▼                 ▼                  ▼
┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐
│  Pod: api-v1    │  │  Pod: api-v2    │  │  Pod: frontend   │
│  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌────────────┐  │
│  │  App:3000 │  │  │  │  App:3000 │  │  │  │  App:80    │  │
│  └─────┬─────┘  │  │  └─────┬─────┘  │  │  └─────┬──────┘  │
│        │        │  │        │        │  │        │         │
│  ┌─────▼─────┐  │  │  ┌─────▼─────┐  │  │  ┌────▼──────┐  │
│  │  Envoy    │  │  │  │  Envoy    │  │  │  │  Envoy    │  │
│  │  sidecar  │◄─┼──┼─►│  sidecar  │◄─┼──┼─►│  sidecar  │  │
│  │  :15001   │  │  │  │  :15001   │  │  │  │  :15001   │  │
│  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │
└─────────────────┘  └─────────────────┘  └──────────────────┘

Traffic Routing (VirtualService):
  api.production.svc.cluster.local
    ├── 90% → api-v1 (stable)   ← canary split
    └── 10% → api-v2 (canary)

mTLS: all pod-to-pod traffic encrypted and mutually authenticated
      (PeerAuthentication: STRICT mode)

Observability: Envoy emits traces → Jaeger, metrics → Prometheus
```

## Usage

```bash
# Install Istio
istioctl install --set profile=default -y

# Enable sidecar injection for namespace
kubectl label namespace production istio-injection=enabled

# Apply traffic management config
kubectl apply -f k8s/

# Check mTLS status
istioctl authn tls-check api-pod.production

# Start canary: send 10% to v2
kubectl apply -f k8s/virtual-service-canary.yaml

# Promote canary to 100% after validation
kubectl apply -f k8s/virtual-service-stable.yaml

# View traffic in Kiali (service mesh dashboard)
istioctl dashboard kiali
```

## Key Decisions

- **`PeerAuthentication: STRICT`** — zero-trust; any pod without a valid cert is rejected
- **`DestinationRule` with circuit breaker** — `outlierDetection` ejects misbehaving pods from load balancing
- **Canary via weight splitting, not DNS** — both versions share one service; no DNS TTL wait
- **`retry` and `timeout` in VirtualService** — resilience without application code changes

## Production Considerations

- Ambient mesh mode (Istio 1.21+) removes the sidecar overhead — L4 via ztunnel, L7 opt-in via waypoint proxies
- Monitor Envoy resource usage — sidecars add ~50MB RAM and ~10ms latency per hop
- Use `AuthorizationPolicy` to enforce which services can talk to which (zero-trust east-west)
- Integrate with Kiali for a real-time service topology map

## Metrics for Success

- 100% of pod-to-pod traffic encrypted (verified by Kiali mTLS graph)
- Canary rollout: full traffic shift in < 5 minutes with zero dropped requests
- Circuit breaker trips within 30s of a backend becoming unhealthy
