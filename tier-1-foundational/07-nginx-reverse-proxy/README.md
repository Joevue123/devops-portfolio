# 07 — Nginx Reverse Proxy & Load Balancer

**Tier:** Foundational | **Skills:** Nginx, SSL/TLS, rate limiting, caching, security headers

## Problem Statement

Directly exposing application servers to the internet is insecure and unscalable. Nginx acts as the edge layer — terminating TLS, distributing load, enforcing rate limits, serving cached content, and adding security headers — all without touching application code.

## Architecture

```
                    Client
                      │
              HTTPS :443 / HTTP :80
                      │
            ┌─────────▼──────────┐
            │       Nginx        │
            │   (Edge Layer)     │
            │                    │
            │  ┌──────────────┐  │
            │  │  SSL/TLS     │  │  ← Let's Encrypt / ACM cert
            │  │  Termination │  │    TLS 1.2+ only, HSTS
            │  └──────┬───────┘  │
            │         │          │
            │  ┌──────▼───────┐  │
            │  │  Rate Limit  │  │  ← 100 req/min per IP
            │  │  Zone        │  │    burst queue of 20
            │  └──────┬───────┘  │
            │         │          │
            │  ┌──────▼───────┐  │
            │  │  Cache       │  │  ← 10m cache for GET /api/*
            │  │  (proxy_     │  │    stale-while-revalidate
            │  │   cache)     │  │
            │  └──────┬───────┘  │
            │         │          │
            │  ┌──────▼───────┐  │
            │  │  Upstream    │  │
            │  │  (weighted   │  │
            │  │   round-     │  │
            │  │   robin)     │  │
            │  └──────┬───────┘  │
            └─────────┼──────────┘
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ App:3000 │ │ App:3001 │ │ App:3002 │
   │ weight=1 │ │ weight=1 │ │ weight=2 │
   └──────────┘ └──────────┘ └──────────┘

Security Headers Added:
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Content-Security-Policy: default-src 'self'
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  Referrer-Policy: strict-origin-when-cross-origin
```

## Usage

```bash
# Test configuration (no restart needed)
nginx -t

# Reload config gracefully (zero downtime)
nginx -s reload

# Start full stack with Docker Compose
docker compose up -d

# Test rate limiting
for i in $(seq 1 120); do curl -s -o /dev/null -w "%{http_code}\n" http://localhost/api/health; done

# Renew Let's Encrypt cert
certbot renew --nginx
```

## Key Decisions

- **Separate `limit_req_zone` per route** — API routes rate-limited more aggressively than static assets
- **`proxy_cache_bypass $http_pragma`** — allows cache bypass with `Pragma: no-cache` for debugging
- **`keepalive 32`** in upstream block — connection pooling to backends reduces TCP overhead
- **`worker_processes auto`** — Nginx scales to available CPU cores automatically

## Configuration Files

```
nginx/
├── nginx.conf              ← Main config (worker, events, http globals)
├── conf.d/
│   ├── upstream.conf       ← Backend server groups
│   ├── ssl.conf            ← TLS settings, cipher suites
│   ├── security.conf       ← Headers, hide server version
│   ├── ratelimit.conf      ← Rate limit zones
│   └── myapp.conf          ← Virtual host, routing, caching
└── certs/                  ← TLS certificates (gitignored)
```

## Production Considerations

- Run behind AWS ALB or Cloudflare for DDoS protection at a higher layer
- Use `ngx_http_geoip2_module` to block traffic by country if required
- Enable `access_log` in JSON format for structured log aggregation
- Monitor `nginx_upstream_response_time` metric for backend latency alerting

## Metrics for Success

- P99 Nginx overhead < 5ms (excluding backend latency)
- Cache hit rate > 60% for cacheable endpoints
- SSL Labs rating: A+
