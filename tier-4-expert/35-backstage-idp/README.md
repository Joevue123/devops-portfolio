# 35 — Backstage Internal Developer Portal

Deploy Spotify's Backstage as an Internal Developer Platform: software catalog, TechDocs, and a service scaffolder template that bootstraps a new microservice with GitHub repo, CI pipeline, ArgoCD app, and Datadog monitors in under 5 minutes.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Developer Experience                                                   │
│                                                                         │
│  Backstage Portal (React SPA + Node.js backend)                         │
│  ├── Software Catalog                                                   │
│  │   ├── Services (catalog-info.yaml in each repo)                      │
│  │   ├── APIs (OpenAPI / AsyncAPI specs)                                │
│  │   ├── Domains (payments, notifications, auth)                        │
│  │   └── Resources (databases, S3 buckets, queues)                      │
│  │                                                                      │
│  ├── TechDocs (mkdocs-in-a-box, stored in S3)                          │
│  │                                                                      │
│  ├── Scaffolder Templates                                               │
│  │   └── new-microservice → creates:                                    │
│  │       ├── GitHub repo (from template)                                │
│  │       ├── ArgoCD Application                                         │
│  │       ├── Datadog dashboard + alert                                  │
│  │       └── catalog-info.yaml (self-registers in catalog)             │
│  │                                                                      │
│  └── Plugins: GitHub, PagerDuty, Lighthouse, SonarQube                 │
│                                                                         │
│  Integrations: GitHub (autodiscovery), PagerDuty, Datadog, Okta        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Problem Statement

New engineers spend their first week figuring out "how do I create a service here?" — which repo template, which CI pipeline, which Helm chart, which monitoring to add. Backstage collapses that into a 5-minute self-service workflow with consistent golden paths.

## Key Files

```
app-config.yaml                              — Backstage configuration (integrations, auth)
catalog/catalog-info.yaml                    — Example service catalog entry
catalog/api-spec.yaml                        — OpenAPI spec registered in catalog
templates/new-microservice/template.yaml     — Scaffolder template for new services
templates/new-microservice/skeleton/         — Cookiecutter-style service skeleton
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| catalog-info.yaml in each repo | Single source of truth, co-located with code, updated by teams |
| GitHub autodiscovery | Scan org for catalog-info.yaml files, no manual registration |
| Scaffolder creates ArgoCD app | Service is immediately deployable after creation, not days later |
| S3 for TechDocs | Docs are pre-built by CI and served statically — no runtime mkdocs |
| Okta integration | SSO avoids managing Backstage users separately |

## Usage

```bash
# Install Backstage (Helm chart)
helm repo add backstage https://backstage.github.io/charts
helm upgrade --install backstage backstage/backstage \
  --namespace backstage --create-namespace \
  -f helm-values.yaml

# Register a service in the catalog
# Add catalog-info.yaml to your repo root, then:
curl -X POST https://backstage.example.com/api/catalog/locations \
  -H "Content-Type: application/json" \
  -d '{"type":"url","target":"https://github.com/org/my-service/blob/main/catalog-info.yaml"}'

# Or use GitHub autodiscovery (finds all catalog-info.yaml in org automatically)
```

## Production Considerations

- **Database** — PostgreSQL for catalog persistence (SQLite only for local dev)
- **Plugin permissions** — RBAC on who can scaffold new services, who can delete catalog entries
- **Template testing** — dry-run scaffolder templates in CI before merging changes
- **Orphan detection** — catalog warns when catalog-info.yaml is deleted but entity still exists

## Success Metrics

- Time to first deploy for a new service: < 5 minutes (from Backstage template)
- Catalog coverage: > 95% of production services registered
- TechDocs pages per service: > 3 (README, runbook, architecture)
