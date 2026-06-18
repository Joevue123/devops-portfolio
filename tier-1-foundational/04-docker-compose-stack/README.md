# 04 — Docker Compose Full-Stack Application

**Tier:** Foundational | **Skills:** Docker Compose, networking, volumes, health checks

## Problem Statement

Running a full application stack locally (and in staging) requires consistent, repeatable environment setup. This project wires together a Node.js API, PostgreSQL, Redis, and Nginx reverse proxy with proper health checks, persistent volumes, and isolated networks.

## Architecture

```
                        Internet
                            │
                    ┌───────▼────────┐
                    │   Nginx :80    │  ← SSL termination,
                    │   :443         │    static file serving,
                    └───────┬────────┘    rate limiting
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
       ┌──────────┐  ┌──────────┐  ┌──────────┐
       │  API 1   │  │  API 2   │  │  API 3   │  ← Horizontally
       │ :3000    │  │ :3000    │  │ :3000    │    scalable
       └─────┬────┘  └─────┬────┘  └─────┬────┘
             │             │             │
             └─────────────┼─────────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
      ┌──────────────┐         ┌──────────────┐
      │  PostgreSQL  │         │    Redis     │
      │  :5432       │         │    :6379     │
      │  (primary    │         │  (sessions,  │
      │   database)  │         │   cache,     │
      └──────────────┘         │   rate limit)│
                               └──────────────┘

Networks:
  frontend-net: nginx ↔ api
  backend-net:  api ↔ postgres, api ↔ redis

Volumes:
  postgres-data: persistent DB storage
  redis-data:    persistent cache
  nginx-logs:    access/error logs
```

## Usage

```bash
# Start full stack
docker compose up -d

# Scale API instances
docker compose up -d --scale api=3

# View logs
docker compose logs -f api

# Run database migrations
docker compose exec api npm run migrate

# Seed development data
docker compose exec api npm run seed

# Stop and clean up
docker compose down -v   # -v removes volumes too
```

## Key Decisions

- **Two isolated networks** — frontend/backend separation; DB is never reachable from Nginx directly
- **Health checks on all services** — Compose waits for DB readiness before starting API (`depends_on: condition: service_healthy`)
- **Named volumes, not bind mounts** — portable across dev machines, works in CI
- **Nginx handles static files** — offloads work from Node.js, serves with `sendfile`

## Production Considerations

- Swap `docker compose` for Kubernetes once you need auto-scaling and self-healing
- Move secrets to Docker Secrets or a vault (not environment variables in `.env`)
- Add a read replica for PostgreSQL to scale reads
- Enable Nginx `proxy_cache` for expensive API responses

## Metrics for Success

- Stack cold-start time < 30 seconds
- API available 0ms after container healthy check passes
- Zero data loss on `docker compose restart`
