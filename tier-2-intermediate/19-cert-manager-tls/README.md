# 19 — Cert-Manager TLS Automation

**Tier:** Intermediate | **Skills:** cert-manager, Let's Encrypt, ACME, Kubernetes, wildcard certs

## Problem Statement

Manually renewing TLS certificates is toil that causes outages when forgotten. cert-manager automates the full lifecycle — request, provision, renew — for any domain in Kubernetes, using Let's Encrypt or internal CAs.

## Architecture

```
cert-manager (in-cluster controller)
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Watches for: Certificate, Ingress (cert annotation)       │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ClusterIssuer: letsencrypt-prod                   │    │
│  │    ACME server: acme-v02.api.letsencrypt.org        │    │
│  │    Challenge: DNS-01 (via Route53)                  │    │
│  │    ← supports wildcard certs (*.example.com)        │    │
│  └─────────────────────────┬───────────────────────────┘    │
│                            │                               │
│  ┌─────────────────────────▼───────────────────────────┐    │
│  │  ACME Challenge Flow                                │    │
│  │                                                     │    │
│  │  1. cert-manager requests cert from Let's Encrypt   │    │
│  │  2. LE returns DNS challenge token                  │    │
│  │  3. cert-manager creates TXT record in Route53      │    │
│  │  4. LE validates DNS record                         │    │
│  │  5. cert-manager stores cert in K8s Secret          │    │
│  │  6. Auto-renew 30 days before expiry               │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Certificate resource:                                      │
│    spec.secretName: api-tls    ← mounted by Ingress         │
│    spec.dnsNames: [api.example.com, *.example.com]          │
│    spec.issuerRef: letsencrypt-prod                         │
└─────────────────────────────────────────────────────────────┘

Ingress (nginx) reads tls.secretName → serves HTTPS automatically

Timeline:
  Day 0:   cert issued (90 day validity)
  Day 60:  cert-manager auto-renews (30 days before expiry)
  Day 90:  old cert expires — already replaced, no outage
```

## Usage

```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true

# Apply issuers and certificate resources
kubectl apply -f k8s/

# Watch certificate provisioning
kubectl get certificate -n production -w
kubectl describe certificate api-tls -n production

# Check cert expiry
kubectl get secret api-tls -n production -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -dates

# Force manual renewal (for testing)
kubectl annotate certificate api-tls -n production \
  cert-manager.io/issuer-kind=ClusterIssuer --overwrite
cmctl renew api-tls -n production
```

## Key Decisions

- **DNS-01 challenge** over HTTP-01 — enables wildcard certs; works for internal services not exposed to internet
- **`ClusterIssuer` not `Issuer`** — one issuer config works across all namespaces
- **Staging issuer first** — Let's Encrypt staging has no rate limits; test the full flow before switching to prod issuer
- **IRSA for Route53 access** — cert-manager pod uses IAM role, no AWS keys stored in Secrets

## Production Considerations

- Monitor certificate expiry with `certmanager_certificate_expiration_timestamp_seconds` Prometheus metric
- Alert at 14 days before expiry (renewal should have happened at 30 days — 14 days means something failed)
- For internal services, use a private CA via `ClusterIssuer` with `vault` type (Vault PKI engine)
- Store the ACME account key in Vault, not a Kubernetes Secret

## Metrics for Success

- Zero manual certificate renewals (cert-manager handles all)
- Certificate renewal completes > 20 days before expiry
- SSL Labs A+ rating on all external endpoints
