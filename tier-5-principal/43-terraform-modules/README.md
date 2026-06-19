# 43 — Org-Scale Terraform Module Registry

Private Terraform module registry with semantic versioning, automated Terratest integration tests, generated documentation, and a GitOps-based release pipeline. Teams consume modules with a single `module` block.

## Architecture

```
Git Monorepo (terraform-modules/)
├── modules/
│   ├── eks/          v3.2.1 — EKS cluster with managed node groups
│   ├── rds/          v2.1.0 — RDS Aurora with read replicas
│   ├── vpc/          v4.0.0 — VPC with public/private/isolated subnets
│   ├── s3-bucket/    v1.5.2 — S3 with encryption, versioning, lifecycle
│   └── iam-role/     v1.2.0 — IAM role with IRSA support
│
├── tests/
│   ├── eks_test.go   — Terratest: provision real EKS, assert outputs, destroy
│   ├── rds_test.go   — Terratest: RDS Aurora, connect + query, destroy
│   └── vpc_test.go   — Terratest: VPC CIDR, subnet count, NAT GW
│
CI Pipeline (on PR):
├── terraform fmt -check
├── terraform validate
├── tflint (lint)
├── terrascan (policy scan)
├── terratest (integration test)
└── terraform-docs (update README)

Release:
git tag modules/eks/v3.2.1  →  GitHub Releases  →  Private registry
```

## Problem Statement

Every team writes their own VPC, EKS, and RDS Terraform — with different security settings, different tagging, different variable names. A module registry enforces consistent, secure-by-default infrastructure with a single version pin.

## Key Files

```
modules/eks/main.tf          — EKS cluster module (managed node groups, IRSA, addons)
modules/rds/main.tf          — RDS Aurora Postgres module (Global DB option)
modules/vpc/main.tf          — VPC module (3-tier: public/private/isolated)
tests/eks_test.go            — Terratest integration test
.github/workflows/release.yml — Semantic release pipeline
```

## Key Decisions

| Decision | Reasoning |
|----------|-----------|
| Git monorepo with tag-based versioning | `modules/eks/v3.2.1` tag pattern enables independent module versioning |
| Terratest over mocked tests | Real AWS resources created and destroyed — catches IAM and service limit issues |
| terraform-docs in CI | Documentation auto-generated from variables/outputs — never out of date |
| terrascan for policy scanning | Catches security misconfigurations before they reach prod |
| CHANGELOG.md per module | Communicate breaking changes (semver major) to consumers |

## Usage

```hcl
# Consumer usage — one block, all standards enforced
module "eks" {
  source  = "git::https://github.com/myorg/terraform-modules.git//modules/eks?ref=modules/eks/v3.2.1"

  cluster_name    = "production"
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids

  node_groups = {
    general = {
      instance_types = ["m5.2xlarge"]
      min_size       = 3
      max_size       = 20
      desired_size   = 5
    }
  }

  tags = { Environment = "production", Team = "platform" }
}
```

```bash
# Run tests for EKS module
cd tests && go test -v -run TestEKS -timeout 60m

# Generate docs
terraform-docs markdown modules/eks/ > modules/eks/README.md

# Release new version
git tag modules/eks/v3.3.0
git push origin modules/eks/v3.3.0
```

## Production Considerations

- **Backward compatibility** — semver major for breaking changes; deprecation warnings in minor
- **Test parallelism** — Terratest parallel mode; each test uses unique resource names
- **Cost guard** — tests run in a dedicated AWS account with budget alert at $500/month
- **Module adoption tracking** — audit `module.source` in all Terraform repos quarterly

## Success Metrics

- Module adoption: > 80% of new infra uses registry modules
- Test runtime: < 30 minutes for full test suite
- Documentation coverage: 100% of input variables have descriptions
- Zero security findings from terrascan in merged modules
