# 17 — AWS Lambda Serverless API

**Tier:** Intermediate | **Skills:** AWS Lambda, API Gateway, Terraform, Python, DynamoDB

## Problem Statement

Not every workload needs a running server. Event-driven functions handle webhooks, async jobs, and infrequent APIs at a fraction of the cost — zero idle compute, automatic scaling, and no server management. This project builds a fully Terraform-managed serverless REST API.

## Architecture

```
Client
  │
  ▼ HTTPS
┌────────────────────────────────────────────────────────────────┐
│  API Gateway v2 (HTTP API)                                     │
│                                                                │
│  Routes:                                                       │
│    GET  /items        → Lambda: list-items                     │
│    POST /items        → Lambda: create-item                    │
│    GET  /items/{id}   → Lambda: get-item                       │
│    DELETE /items/{id} → Lambda: delete-item                    │
│                                                                │
│  Authorizer: JWT (Cognito)  ← validates Bearer token           │
│  Throttling: 1000 RPS burst, 500 RPS steady                    │
│  CORS: configured per-route                                    │
└────────────────────────────┬───────────────────────────────────┘
                             │ invoke
                             ▼
┌────────────────────────────────────────────────────────────────┐
│  Lambda Functions (Python 3.12, arm64 / Graviton)              │
│                                                                │
│  Runtime: 512MB RAM, 30s timeout                               │
│  Deployment: zip artifact from CI (or container image)         │
│  IAM role: least-privilege (only DynamoDB:GetItem etc.)        │
│  Layers: shared dependencies (boto3, pydantic)                 │
│  X-Ray tracing: enabled                                        │
└────────────────────────────┬───────────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────┐
│  DynamoDB (on-demand capacity mode)                            │
│                                                                │
│  Table: items                                                  │
│    PK: id (String)                                             │
│    GSI: by-owner-index (owner_id, created_at)                  │
│  TTL attribute: expires_at  ← auto-delete old items            │
│  Point-in-time recovery: enabled                               │
└────────────────────────────────────────────────────────────────┘

Cost model: pay per invocation (~$0.20 per 1M requests)
vs EC2 t3.small: $15/month running idle
```

## Usage

```bash
# Package Lambda functions
cd lambda && pip install -r requirements.txt -t ./package && \
  zip -r ../lambda.zip . && cd ..

# Deploy infrastructure
terraform init
terraform apply -var="environment=staging"

# Invoke directly (bypass API Gateway for testing)
aws lambda invoke \
  --function-name items-list-staging \
  --payload '{"httpMethod":"GET","path":"/items"}' \
  response.json && cat response.json

# Tail Lambda logs
aws logs tail /aws/lambda/items-list-staging --follow

# Destroy
terraform destroy -var="environment=staging"
```

## Key Decisions

- **`arm64` / Graviton runtime** — 20% cheaper and often faster than x86 for Python workloads
- **API Gateway v2 (HTTP API)** over REST API — 70% cheaper, lower latency, simpler config
- **On-demand DynamoDB** — zero capacity planning; scales to any RPS without pre-provisioning
- **Lambda Powertools** — structured logging, tracing, and metrics with one decorator

## Production Considerations

- Use Lambda container images (not zip) for reproducible builds and images > 50MB
- Set reserved concurrency to prevent one function from consuming the account limit
- Add a dead-letter queue (SQS/SNS) for async invocations to catch silent failures
- Use Provisioned Concurrency for latency-sensitive APIs to eliminate cold starts

## Metrics for Success

- Cold start time < 500ms (Python with Graviton and slim dependencies)
- API p99 latency < 200ms for DynamoDB reads
- Cost < $5/month at 10M requests/month
