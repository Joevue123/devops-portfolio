# 26 — Blue/Green Deployment with Instant Rollback

**Tier:** Advanced | **Skills:** Blue/green deployments, Kubernetes Services, instant rollback, smoke testing

## Problem Statement

Rolling updates take minutes to complete and partial rollback is complex. Blue/green keeps both versions live simultaneously — switch is a single Service selector change (< 1 second), rollback is the same command in reverse.

## Architecture

```
                      Users
                        │
                        ▼
              ┌──────────────────┐
              │  Service: api    │
              │  selector:       │
              │    slot: blue ◄──┼── single field change = instant switch
              │      OR          │
              │    slot: green   │
              └────────┬─────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
    ┌─────▼──────┐           ┌──────▼─────┐
    │ Deployment │           │ Deployment │
    │  api-blue  │           │ api-green  │
    │  (v1.2.0)  │           │  (v1.3.0)  │
    │  replicas:3│           │  replicas:3│
    │            │           │            │
    │  LIVE ✓    │           │  STANDBY   │
    │  (current) │           │  (new ver) │
    └────────────┘           └────────────┘

Deployment sequence:
  1. Deploy v1.3.0 to GREEN (inactive slot)
  2. Run smoke tests against GREEN directly
  3. kubectl patch service api -p '{"spec":{"selector":{"slot":"green"}}}'
     → Switch happens in < 1 second, zero dropped requests
  4. Monitor GREEN for 10 minutes
  5. PASS → delete or scale down BLUE
     FAIL → kubectl patch service api -p '{"spec":{"selector":{"slot":"blue"}}}'
             → Back on v1.2.0 in < 1 second

Database considerations:
  Backward-compatible migrations only (never drop columns until old version is gone)
  Or: separate migration job runs before switch, with feature flags for new schema
```

## Usage

```bash
# Determine current active slot
ACTIVE=$(kubectl get svc api -n production -o jsonpath='{.spec.selector.slot}')
INACTIVE=$([ "$ACTIVE" = "blue" ] && echo "green" || echo "blue")
echo "Active: $ACTIVE  |  Deploying to: $INACTIVE"

# Deploy new version to inactive slot
kubectl set image deployment/api-${INACTIVE} api=myapp:v1.3.0 -n production
kubectl rollout status deployment/api-${INACTIVE} -n production

# Run smoke tests against inactive slot directly
./scripts/smoke-test.sh ${INACTIVE}

# Switch traffic (< 1 second)
kubectl patch service api -n production \
  -p "{\"spec\":{\"selector\":{\"slot\":\"${INACTIVE}\"}}}"

echo "Switched to ${INACTIVE}. Monitor for 10 minutes then clean up ${ACTIVE}."

# Rollback (if needed)
kubectl patch service api -n production \
  -p "{\"spec\":{\"selector\":{\"slot\":\"${ACTIVE}\"}}}"
```

## Key Decisions

- **Both slots always at full replicas** — instant switch, no scale-up lag under load
- **Smoke test before switch** — hit the inactive deployment directly via pod IP before it goes live
- **Feature flags for DB migrations** — deploy code that reads new schema but writes old until switch
- **Automated switch script** — no manual `kubectl patch` in runbooks; encode the logic

## Production Considerations

- Double the compute cost during the switch window — acceptable for critical services
- Use `kubectl patch --dry-run=server` to validate the switch command before executing
- Keep inactive slot warm for 30 minutes post-switch — instant rollback window
- Blue/green works best for stateless services; stateful workloads need more care with session affinity

## Metrics for Success

- Switch time < 2 seconds (Service selector update propagation)
- Rollback time < 2 seconds
- Zero failed requests during switch (measured by Prometheus)
