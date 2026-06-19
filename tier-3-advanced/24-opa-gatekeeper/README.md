# 24 — OPA Gatekeeper Policy Enforcement

**Tier:** Advanced | **Skills:** OPA, Gatekeeper, Rego, admission control, policy-as-code

## Problem Statement

Teams deploy containers as root, without resource limits, from untrusted registries, and Kubernetes allows it all by default. OPA Gatekeeper is a Kubernetes admission controller that enforces policy-as-code — every resource is validated before it reaches etcd.

## Architecture

```
kubectl apply / helm install / ArgoCD sync
                │
                ▼
┌───────────────────────────────────────────────────────────────┐
│  Kubernetes API Server                                       │
│                                                               │
│  Admission Webhook → OPA Gatekeeper                          │
│    (ValidatingAdmissionWebhook)                              │
└───────────────────────────┬───────────────────────────────────┘
                            │ AdmissionReview request
                            ▼
┌───────────────────────────────────────────────────────────────┐
│  OPA Gatekeeper                                              │
│                                                               │
│  ConstraintTemplate (Rego policy definition)                  │
│    ↓ instantiated by ↓                                       │
│  Constraint (enforcement config)                             │
│                                                               │
│  Active Policies:                                            │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  require-resource-limits                            │     │
│  │    DENY: containers without cpu+memory limits       │     │
│  │                                                     │     │
│  │  block-privileged-containers                        │     │
│  │    DENY: securityContext.privileged: true           │     │
│  │                                                     │     │
│  │  require-non-root                                   │     │
│  │    DENY: runAsNonRoot != true                       │     │
│  │                                                     │     │
│  │  allowed-registries                                 │     │
│  │    DENY: image not from ecr.aws.com or harbor.*     │     │
│  │                                                     │     │
│  │  require-labels                                     │     │
│  │    DENY: missing app.kubernetes.io/name label       │     │
│  │                                                     │     │
│  │  no-latest-tag                                      │     │
│  │    DENY: image tag is "latest"                      │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                               │
│  Enforcement: dryrun → warn → deny                           │
│    dryrun: log violations, allow resource                    │
│    warn: allow with warning in kubectl output                │
│    deny: block the request, return error message             │
└───────────────────────────────────────────────────────────────┘
```

## Usage

```bash
# Install Gatekeeper
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace

# Apply constraint templates (Rego policy definitions)
kubectl apply -f templates/

# Apply constraints (enforcement rules)
kubectl apply -f constraints/

# Test a violation
kubectl run bad-pod --image=nginx:latest --restart=Never
# Error: [no-latest-tag] container "bad-pod" has an invalid image tag "latest"

# Audit existing violations (dryrun mode)
kubectl get constraint -o json | jq '.items[].status.byPod[].constraintUID'

# See all current violations
kubectl get k8sallowedregistries.constraints.gatekeeper.sh -o yaml
```

## Key Decisions

- **Start in `dryrun` mode** — audit violations without breaking existing workloads; fix then switch to `deny`
- **Exempt `kube-system` and `gatekeeper-system`** — system components must not be policy-blocked
- **Rego unit tests alongside templates** — `opa test templates/` catches policy regressions in CI
- **Mutation webhooks for auto-fix** — MutatingAdmissionWebhook adds missing labels automatically instead of blocking

## Production Considerations

- Use Policy Controller (Sigstore) alongside Gatekeeper to enforce image signing — only signed images from trusted registries
- Version ConstraintTemplates in Git and deploy via ArgoCD — policy changes go through PR review
- Monitor `gatekeeper_violations_total` Prometheus metric to track policy compliance over time
- Write `warn` messages that tell engineers *exactly* what to change, not just that they failed

## Metrics for Success

- 100% of production Deployments pass all constraints
- Zero containers running as root in production namespace
- Policy violation PR feedback time < 30 seconds (fast admission response)
