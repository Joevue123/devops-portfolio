# 41 — AI/ML Platform on Kubernetes

Production-grade ML platform: GPU NodePool with Karpenter, Kubeflow Pipelines for workflow orchestration, MLflow for experiment tracking and model registry, and Seldon Core for model serving with canary deployments.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  Data Scientists / ML Engineers                                      │
│  jupyter notebook / python script → submit pipeline                  │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────────┐
│  Kubeflow Pipelines                                                  │
│  ├── data-prep   (CPU pod, reads from S3)                            │
│  ├── train       (GPU pod, p3.2xlarge via Karpenter)                 │
│  ├── evaluate    (CPU, compares metrics vs. baseline)                │
│  └── register    (MLflow model registry, promotes if better)         │
│                           │                                          │
│  MLflow                   │                                          │
│  ├── Experiment tracking  │  (metrics, params, artifacts)            │
│  ├── Model Registry       │  (staging → production promotion)        │
│  └── Artifact Store       →  S3 bucket                              │
│                           │                                          │
│  Seldon Core              │                                          │
│  ├── SeldonDeployment     ◄─ deploys registered model                │
│  ├── Canary (10% → 100%) via Istio                                   │
│  └── Prometheus metrics  (predict_requests_total, latency)           │
└──────────────────────────────────────────────────────────────────────┘

GPU Scheduling:
Karpenter NodePool: p3/g4dn instances, spot-first, scale-to-zero
NVIDIA device plugin: exposes nvidia.com/gpu resource
ResourceQuota: per-namespace GPU limits (prevents runaway costs)
```

## Problem Statement

ML teams need GPU compute on-demand without provisioning dedicated nodes. Data scientists shouldn't need to know Kubernetes — they submit pipelines and get results. Platform provides self-service with guardrails.

## Key Files

```
k8s/gpu-nodepool.yaml           — Karpenter NodePool for p3/g4dn instances
k8s/mlflow.yaml                 — MLflow deployment + S3 artifact store
k8s/kubeflow-pipeline.yaml      — KFP pipeline SDK example (train + register)
k8s/seldon-deployment.yaml      — SeldonDeployment with canary + monitoring
k8s/gpu-quota.yaml              — ResourceQuota: max 8 GPUs per namespace
scripts/promote-model.sh        — Promote model from staging to production
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Karpenter for GPU nodes | Scale-to-zero prevents idle p3 instances burning $3/hr overnight |
| MLflow over Kubeflow model registry | MLflow is simpler, language-agnostic, integrates with all frameworks |
| Seldon over plain Deployment | Built-in A/B testing, shadow mode, explainability endpoints |
| S3 for artifact store | Unlimited storage, accessible from any region/cluster |
| GPU quota per namespace | Prevents one team from monopolizing all GPU capacity |

## Usage

```bash
# Install NVIDIA device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/nvidia-device-plugin.yml

# Deploy MLflow
kubectl apply -f k8s/mlflow.yaml

# Submit a training pipeline
python pipeline.py --experiment-name my-experiment --epochs 50

# Check running pipeline
kubectl get pods -n kubeflow -l pipeline/runid=<run-id>

# Deploy model to serving
kubectl apply -f k8s/seldon-deployment.yaml

# Test prediction endpoint
curl -X POST http://seldon-gateway/api/v1.0/predictions \
  -H 'Content-Type: application/json' \
  -d '{"data": {"ndarray": [[1.0, 2.0, 3.0]]}}'

# Promote best model
./scripts/promote-model.sh --experiment my-experiment --metric val_accuracy --threshold 0.95
```

## Production Considerations

- **GPU time limits** — LimitRange caps single training job to 24 hours; long runs need checkpointing
- **Spot interruption handling** — Kubeflow retries failed steps; checkpoints written to S3 every 10 min
- **Model lineage** — MLflow logs dataset hash + code version so any model can be reproduced
- **Data versioning** — DVC or Delta Lake for dataset versioning alongside model versioning

## Success Metrics

- GPU utilization: > 70% during business hours (vs. < 20% with always-on nodes)
- Model deployment time: < 15 minutes from MLflow registration to serving endpoint
- GPU node cold-start: < 4 minutes (Karpenter + NVIDIA plugin initialization)
