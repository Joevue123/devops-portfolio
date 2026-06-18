# 01 — Linux System Health Monitor

**Tier:** Foundational | **Skills:** Bash, cron, alerting, sysadmin

## Problem Statement

Ops teams need early warning on resource exhaustion before services degrade. This monitor tracks CPU, memory, disk, and network — with configurable thresholds and Slack/email alerting — all in a single dependency-free Bash script.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Linux Host                         │
│                                                     │
│  ┌──────────┐    ┌──────────┐    ┌───────────────┐ │
│  │  /proc   │    │   df     │    │   ss / ip     │ │
│  │ cpu/mem  │    │  disk    │    │   network     │ │
│  └────┬─────┘    └────┬─────┘    └──────┬────────┘ │
│       │               │                 │           │
│       └───────────────┴─────────────────┘           │
│                       │                             │
│              ┌────────▼────────┐                    │
│              │  monitor.sh     │                    │
│              │  (threshold     │                    │
│              │   checks)       │                    │
│              └────────┬────────┘                    │
│                       │                             │
│          ┌────────────┼────────────┐                │
│          ▼            ▼            ▼                │
│     ┌─────────┐  ┌────────┐  ┌──────────┐          │
│     │  /var/  │  │ Slack  │  │  Email   │          │
│     │  log/   │  │webhook │  │ (mail)   │          │
│     │ health  │  └────────┘  └──────────┘          │
│     └─────────┘                                     │
└─────────────────────────────────────────────────────┘

Cron triggers monitor.sh every 5 minutes
```

## Usage

```bash
# Make executable
chmod +x monitor.sh

# Run manually
./monitor.sh

# Install as cron job (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /path/to/monitor.sh >> /var/log/system-health.log 2>&1") | crontab -

# Configure thresholds and alerting
cp config.env.example config.env
vim config.env
```

## Key Decisions

- **Pure Bash, no dependencies** — works on any Linux host without installing Python/Go/etc.
- **Configurable thresholds via env file** — ops can tune without editing the script
- **Idempotent log rotation** — uses `logrotate`-compatible output so it integrates with existing tooling
- **Slack webhook over SMTP** — simpler ops, most teams have Slack; email is opt-in fallback

## Production Considerations

- Ship logs to a central aggregator (Loki, CloudWatch) rather than local disk
- Replace cron with systemd timer for better failure visibility
- Add PagerDuty integration for on-call escalation
- Containerize and deploy as a DaemonSet in Kubernetes

## Metrics for Success

- Alert lag < 30s from threshold breach to notification
- Zero false positives per week (tune thresholds to baseline)
- Script runtime < 2s per execution
