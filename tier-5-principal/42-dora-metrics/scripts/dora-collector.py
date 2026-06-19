#!/usr/bin/env python3
"""
DORA metrics collector — polls GitHub and PagerDuty, pushes to Prometheus Pushgateway.
Runs as a Kubernetes CronJob every 15 minutes.
"""
import os
import time
import datetime
import argparse
import requests
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway


GITHUB_TOKEN    = os.environ["GITHUB_TOKEN"]
PAGERDUTY_TOKEN = os.environ["PAGERDUTY_TOKEN"]
PUSHGATEWAY_URL = os.environ.get("PUSHGATEWAY_URL", "http://prometheus-pushgateway:9091")
ORG             = os.environ.get("GITHUB_ORG", "myorg")

GH_HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}
PD_HEADERS = {
    "Authorization": f"Token token={PAGERDUTY_TOKEN}",
    "Accept": "application/vnd.pagerduty+json;version=2",
}


def since_timestamp(days: int) -> str:
    dt = datetime.datetime.utcnow() - datetime.timedelta(days=days)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def get_deployments(repo: str, days: int) -> list[dict]:
    """Return list of successful production deployments in the last N days."""
    url = f"https://api.github.com/repos/{ORG}/{repo}/deployments"
    params = {"environment": "production", "per_page": 100}
    resp = requests.get(url, headers=GH_HEADERS, params=params, timeout=10)
    resp.raise_for_status()
    since = time.time() - days * 86400
    return [
        d for d in resp.json()
        if datetime.datetime.fromisoformat(
            d["created_at"].replace("Z", "+00:00")
        ).timestamp() > since
    ]


def get_lead_time_seconds(repo: str, deploy: dict) -> float | None:
    """Lead time = deploy timestamp - earliest commit in the PR that triggered it."""
    sha = deploy.get("sha")
    if not sha:
        return None
    # Find PR merged at this SHA
    url = f"https://api.github.com/repos/{ORG}/{repo}/commits/{sha}/pulls"
    resp = requests.get(url, headers=GH_HEADERS, timeout=10)
    if resp.status_code != 200 or not resp.json():
        return None
    pr = resp.json()[0]
    pr_created = datetime.datetime.fromisoformat(pr["created_at"].replace("Z", "+00:00")).timestamp()
    deploy_time = datetime.datetime.fromisoformat(deploy["created_at"].replace("Z", "+00:00")).timestamp()
    return max(0, deploy_time - pr_created)


def get_incidents(days: int, team_id: str | None = None) -> list[dict]:
    """Return P1/P2 incidents resolved in the last N days."""
    url = "https://api.pagerduty.com/incidents"
    params = {
        "since": since_timestamp(days),
        "urgency": "high",
        "statuses[]": ["resolved"],
        "limit": 100,
    }
    if team_id:
        params["team_ids[]"] = team_id
    resp = requests.get(url, headers=PD_HEADERS, params=params, timeout=10)
    resp.raise_for_status()
    return resp.json().get("incidents", [])


def compute_mttr_seconds(incidents: list[dict]) -> float:
    """Median time from incident created to resolved."""
    durations = []
    for inc in incidents:
        created = datetime.datetime.fromisoformat(inc["created_at"].replace("Z", "+00:00")).timestamp()
        resolved_at = inc.get("resolved_at")
        if not resolved_at:
            continue
        resolved = datetime.datetime.fromisoformat(resolved_at.replace("Z", "+00:00")).timestamp()
        durations.append(resolved - created)
    if not durations:
        return 0.0
    durations.sort()
    mid = len(durations) // 2
    return durations[mid] if len(durations) % 2 else (durations[mid - 1] + durations[mid]) / 2


def compute_change_failure_rate(deployments: list[dict], incidents: list[dict]) -> float:
    """% of deploys followed by a P1/P2 incident within 1 hour."""
    if not deployments:
        return 0.0
    incident_times = [
        datetime.datetime.fromisoformat(i["created_at"].replace("Z", "+00:00")).timestamp()
        for i in incidents
    ]
    failures = 0
    for d in deployments:
        deploy_time = datetime.datetime.fromisoformat(d["created_at"].replace("Z", "+00:00")).timestamp()
        if any(0 <= (t - deploy_time) <= 3600 for t in incident_times):
            failures += 1
    return failures / len(deployments)


def collect_and_push(repos: list[str], days: int, team: str, team_pd_id: str | None = None):
    registry = CollectorRegistry()

    g_df = Gauge("dora_deployment_frequency_per_day", "Deployments per day",
                 ["team", "repo"], registry=registry)
    g_lt = Gauge("dora_lead_time_seconds", "Median lead time from commit to deploy (seconds)",
                 ["team", "repo"], registry=registry)
    g_mttr = Gauge("dora_mttr_seconds", "Median MTTR in seconds",
                   ["team"], registry=registry)
    g_cfr = Gauge("dora_change_failure_rate", "Change failure rate (0-1)",
                  ["team"], registry=registry)

    all_deployments = []
    for repo in repos:
        deployments = get_deployments(repo, days)
        all_deployments.extend(deployments)

        df = len(deployments) / days
        g_df.labels(team=team, repo=repo).set(df)
        print(f"  {repo}: {len(deployments)} deploys in {days}d → {df:.2f}/day")

        lead_times = [lt for d in deployments if (lt := get_lead_time_seconds(repo, d)) is not None]
        if lead_times:
            lead_times.sort()
            median_lt = lead_times[len(lead_times) // 2]
            g_lt.labels(team=team, repo=repo).set(median_lt)
            print(f"  {repo}: median lead time {median_lt/3600:.1f}h")

    incidents = get_incidents(days, team_pd_id)
    mttr = compute_mttr_seconds(incidents)
    cfr  = compute_change_failure_rate(all_deployments, incidents)
    g_mttr.labels(team=team).set(mttr)
    g_cfr.labels(team=team).set(cfr)
    print(f"  MTTR: {mttr/3600:.1f}h | CFR: {cfr*100:.1f}%")

    push_to_gateway(PUSHGATEWAY_URL, job=f"dora-{team}", registry=registry)
    print(f"  Pushed to {PUSHGATEWAY_URL}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repos", nargs="+", default=["api", "frontend", "worker"])
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--team", default="platform")
    parser.add_argument("--pd-team-id", default=None)
    args = parser.parse_args()

    print(f"Collecting DORA metrics: team={args.team} repos={args.repos} window={args.days}d")
    collect_and_push(args.repos, args.days, args.team, args.pd_team_id)
