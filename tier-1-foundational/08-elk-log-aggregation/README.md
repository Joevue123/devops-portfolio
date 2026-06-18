# 08 — ELK Stack Log Aggregation

**Tier:** Foundational | **Skills:** Elasticsearch, Logstash, Kibana, Filebeat, log parsing

## Problem Statement

Logs scattered across dozens of servers are impossible to correlate or search. The ELK stack centralizes logs from any source, enriches them with structured fields, and enables real-time search and dashboards — all running locally or in Docker Compose.

## Architecture

```
Log Sources
┌──────────────────────────────────────────────────────────┐
│  Application Servers                                     │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐         │
│  │  App Logs  │  │ Nginx Logs │  │System Logs │         │
│  │  (JSON)    │  │(access.log)│  │(/var/log/) │         │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘         │
│         └──────────┬────┘               │               │
│                    │  Filebeat agent     │               │
│                    │  (lightweight)      │               │
└────────────────────┼─────────────────────┘               
                     │
                     ▼ (TLS + auth)
┌────────────────────────────────────────────────────────┐
│                   Logstash :5044                        │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Input: beats { port => 5044 }                   │  │
│  │                                                  │  │
│  │  Filter:                                         │  │
│  │    grok  → parse nginx Combined Log Format       │  │
│  │    json  → parse structured app logs             │  │
│  │    geoip → enrich IP → country, city, coords     │  │
│  │    useragent → parse browser/OS from UA string   │  │
│  │    mutate → normalize field names                │  │
│  │    date  → parse timestamps to @timestamp        │  │
│  │                                                  │  │
│  │  Output: elasticsearch { ... }                   │  │
│  └──────────────────────────────────────────────────┘  │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│             Elasticsearch :9200                        │
│                                                        │
│  Indices:                                              │
│    logs-app-YYYY.MM.DD    (ILM: hot→warm→delete)       │
│    logs-nginx-YYYY.MM.DD                               │
│    logs-system-YYYY.MM.DD                              │
│                                                        │
│  ILM Policy:                                           │
│    Hot  (0-7d):   primary shards, full indexing        │
│    Warm (7-30d):  replica removed, searchable          │
│    Delete (30d+): auto-purge                           │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                  Kibana :5601                           │
│                                                        │
│  Dashboards:                                           │
│    • Application error rate over time                  │
│    • HTTP 4xx/5xx breakdown by endpoint                │
│    • Geographic traffic map                            │
│    • Slowest API endpoints (p95 response time)         │
│    • Log level distribution (ERROR/WARN/INFO)          │
└────────────────────────────────────────────────────────┘
```

## Usage

```bash
# Start the full stack
docker compose up -d

# Wait for Elasticsearch to be healthy
until curl -s http://localhost:9200/_cluster/health | grep -q '"status":"green"'; do sleep 5; done

# Import Kibana dashboards
curl -X POST "localhost:5601/api/saved_objects/_import" \
  -H "kbn-xsrf: true" \
  --form file=@kibana/dashboards/app-overview.ndjson

# Send a test log
echo '{"level":"error","message":"test error","service":"api","timestamp":"2024-01-01T00:00:00Z"}' \
  >> /var/log/app/app.log

# Search logs via API
curl -X GET "localhost:9200/logs-app-*/_search" -H 'Content-Type: application/json' -d'
{
  "query": { "match": { "level": "error" } },
  "sort": [{ "@timestamp": "desc" }],
  "size": 10
}'
```

## Key Decisions

- **Index Lifecycle Management (ILM)** — automatic data tiering prevents disk exhaustion
- **Filebeat over Logstash agent** — lightweight on source hosts; Logstash only on the aggregation server
- **Grok patterns in Logstash, not app code** — log format changes don't require app redeployment
- **JSON structured logging** — no regex parsing needed; fields indexed automatically

## Production Considerations

- Run Elasticsearch as a 3-node cluster for high availability and replication
- Enable X-Pack security (TLS + RBAC) — never run open to the internet
- Consider OpenSearch as a drop-in alternative to avoid Elastic licensing costs
- Use Kafka between Filebeat and Logstash to handle log bursts without backpressure

## Metrics for Success

- Log ingestion lag < 10 seconds from write to searchable
- Elasticsearch query p99 < 500ms for last-hour searches
- Disk usage stable (ILM purging old data on schedule)
