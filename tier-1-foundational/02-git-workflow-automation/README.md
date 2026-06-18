# 02 — Git Workflow Automation

**Tier:** Foundational | **Skills:** Git hooks, pre-commit, shell scripting, code quality

## Problem Statement

Teams waste review cycles on formatting issues, accidentally commit secrets, and use inconsistent branch/commit naming. This project enforces standards automatically at commit time — before bad code ever reaches CI.

## Architecture

```
Developer Workstation
┌──────────────────────────────────────────────────────┐
│                                                      │
│  git commit / git push                               │
│         │                                            │
│         ▼                                            │
│  ┌─────────────────────────────────────────────┐     │
│  │              .git/hooks/                    │     │
│  │                                             │     │
│  │  pre-commit ──► secret scan (detect-secrets)│     │
│  │              ──► lint (shellcheck/eslint)   │     │
│  │              ──► format check (prettier)    │     │
│  │              ──► unit tests (fast subset)   │     │
│  │                                             │     │
│  │  commit-msg ──► conventional commits format │     │
│  │                                             │     │
│  │  pre-push   ──► branch naming policy        │     │
│  │              ──► no force-push to main      │     │
│  └──────────────────────┬──────────────────────┘     │
│                         │                            │
│              ┌──────────┴──────────┐                 │
│              │  PASS               │  FAIL           │
│              │  commit proceeds    │  commit blocked  │
│              │                     │  error message  │
│              └─────────────────────┘                 │
└──────────────────────────────────────────────────────┘

CI/CD (GitHub Actions / GitLab CI)
  └── Same checks run server-side as safety net
```

## Usage

```bash
# Install hooks into a repo
./install-hooks.sh /path/to/your/repo

# Or use pre-commit framework (recommended for teams)
pip install pre-commit
pre-commit install
pre-commit run --all-files  # run against all files manually

# Test the commit-msg hook
echo "bad commit message" | .git/hooks/commit-msg /dev/stdin   # should fail
echo "feat(api): add rate limiting" | .git/hooks/commit-msg /dev/stdin  # should pass
```

## Key Decisions

- **pre-commit framework** over raw hooks — versioned, shareable, language-agnostic
- **Fail fast on secrets** — `detect-secrets` runs first before any expensive checks
- **Conventional Commits** enforced — enables automatic changelog generation and semver bumping
- **Branch pattern `(feat|fix|chore|hotfix)/TICKET-description`** — links work to ticket systems

## Production Considerations

- Pin hook versions in `.pre-commit-config.yaml` to prevent surprise breakage
- Add `--no-verify` escape hatch documentation so devs aren't blocked in emergencies
- Sync server-side CI checks with local hooks (single source of truth in `.pre-commit-config.yaml`)
- Store secrets baseline (`detect-secrets` audit file) in repo for team-wide false-positive management

## Metrics for Success

- Secrets committed to repo: 0
- CI failures from formatting/lint issues: < 5% of PRs
- Hook execution time: < 10 seconds for typical commit
