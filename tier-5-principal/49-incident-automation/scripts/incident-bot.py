#!/usr/bin/env python3
"""
Incident response bot — PagerDuty webhook → Slack war-room + auto-diagnosis.
Runs as a Kubernetes Deployment with cluster read access.
"""
import hashlib
import hmac
import json
import logging
import os
import subprocess
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

import yaml
from slack_sdk import WebClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

SLACK_TOKEN       = os.environ["SLACK_BOT_TOKEN"]
PD_WEBHOOK_SECRET = os.environ.get("PAGERDUTY_WEBHOOK_SECRET", "")
RUNBOOK_DIR       = os.environ.get("RUNBOOK_DIR", "/runbooks")
GITHUB_TOKEN      = os.environ.get("GITHUB_TOKEN", "")
GITHUB_REPO       = os.environ.get("GITHUB_REPO", "myorg/platform")

slack = WebClient(token=SLACK_TOKEN)


def verify_pagerduty_signature(body: bytes, signature: str) -> bool:
    """Verify PagerDuty V3 webhook HMAC-SHA256 signature."""
    if not PD_WEBHOOK_SECRET:
        return True
    expected = "v1=" + hmac.new(
        PD_WEBHOOK_SECRET.encode(), body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def create_war_room(incident: dict) -> str:
    """Create a Slack channel for this incident, return channel ID."""
    inc_id   = incident["id"]
    service  = incident.get("service", {}).get("summary", "unknown").lower().replace(" ", "-")
    title    = f"incident-{inc_id[-6:]}-{service}"[:80]

    try:
        result = slack.conversations_create(name=title, is_private=False)
        channel_id = result["channel"]["id"]
        log.info(f"Created war-room: #{title} ({channel_id})")
    except Exception as e:
        if "name_taken" in str(e):
            result = slack.conversations_list(types="public_channel")
            for ch in result["channels"]:
                if ch["name"] == title:
                    return ch["id"]
        raise

    # Post incident summary
    slack.chat_postMessage(
        channel=channel_id,
        blocks=[
            {"type": "header", "text": {"type": "plain_text", "text": f"🚨 Incident: {incident['title']}"}},
            {"type": "section", "fields": [
                {"type": "mrkdwn", "text": f"*Severity:* {incident.get('urgency', 'unknown').upper()}"},
                {"type": "mrkdwn", "text": f"*Service:* {service}"},
                {"type": "mrkdwn", "text": f"*Started:* {incident.get('created_at', 'unknown')}"},
                {"type": "mrkdwn", "text": f"*PagerDuty:* <{incident.get('html_url', '#')}|View Incident>"},
            ]},
            {"type": "section", "text": {"type": "mrkdwn", "text": "_Running auto-diagnosis... results in ~60 seconds_"}},
        ]
    )
    return channel_id


def run_diagnostics(service_name: str, channel_id: str):
    """Run kubectl diagnostics and post results to the war-room channel."""
    namespace = "production"
    commands = {
        "Pod Status":        f"kubectl get pods -n {namespace} -l app={service_name} --no-headers",
        "Recent Events":     f"kubectl get events -n {namespace} --field-selector involvedObject.name={service_name} --sort-by='.lastTimestamp' | tail -10",
        "Last Deployment":   f"kubectl rollout history deployment/{service_name} -n {namespace} 2>/dev/null | tail -3",
        "Error Rate (5m)":   f"kubectl exec -n monitoring -l app=prometheus -- promtool query instant 'sum(rate(http_requests_total{{code=~\"5..\",job=\"{service_name}\"}}[5m]))'",
    }

    results = []
    for label, cmd in commands.items():
        try:
            output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, timeout=10).decode().strip()
            results.append(f"*{label}:*\n```{output[:500]}```")
        except subprocess.CalledProcessError as e:
            results.append(f"*{label}:* Error — `{e.output.decode()[:100].strip()}`")
        except subprocess.TimeoutExpired:
            results.append(f"*{label}:* Timed out")

    # Find and run matching runbook
    runbook_steps = load_runbook(service_name)

    slack.chat_postMessage(
        channel=channel_id,
        blocks=[
            {"type": "header", "text": {"type": "plain_text", "text": "Auto-Diagnosis Results"}},
            {"type": "section", "text": {"type": "mrkdwn", "text": "\n\n".join(results)}},
            {"type": "divider"},
            {"type": "section", "text": {"type": "mrkdwn", "text": f"*Runbook steps:*\n{runbook_steps}"}},
        ]
    )


def load_runbook(service_name: str) -> str:
    """Load applicable runbook manual steps."""
    runbook_file = os.path.join(RUNBOOK_DIR, "high-error-rate.yaml")
    if not os.path.exists(runbook_file):
        return "_No runbook found — check https://runbook.example.com_"
    with open(runbook_file) as f:
        rb = yaml.safe_load(f)
    steps = rb.get("manual_steps", [])
    return "\n".join(f"{i+1}. {s}" for i, s in enumerate(steps))


def handle_triggered(event: dict):
    incident = event.get("incident", {})
    service  = incident.get("service", {}).get("summary", "unknown")
    log.info(f"Handling triggered incident: {incident.get('id')} ({service})")

    channel_id = create_war_room(incident)
    run_diagnostics(service.lower().replace(" ", "-"), channel_id)


def handle_resolved(event: dict):
    incident = event.get("incident", {})
    inc_id   = incident.get("id", "unknown")
    log.info(f"Incident resolved: {inc_id}")

    service  = incident.get("service", {}).get("summary", "unknown").lower().replace(" ", "-")
    title    = f"incident-{inc_id[-6:]}-{service}"[:80]

    try:
        result = slack.conversations_list(types="public_channel")
        for ch in result["channels"]:
            if ch["name"] == title:
                resolved_at = datetime.now(tz=timezone.utc).isoformat()
                slack.chat_postMessage(
                    channel=ch["id"],
                    text=f"✅ *Incident resolved at {resolved_at}*\nPost-mortem template: create an issue in {GITHUB_REPO} within 5 business days."
                )
                break
    except Exception as e:
        log.error(f"Failed to post resolution to Slack: {e}")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/webhook/pagerduty":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        body   = self.rfile.read(length)
        sig    = self.headers.get("X-PagerDuty-Signature", "")

        if not verify_pagerduty_signature(body, sig):
            log.warning("Invalid PagerDuty signature")
            self.send_response(401)
            self.end_headers()
            return

        try:
            payload = json.loads(body)
            for event in payload.get("messages", [payload]):
                event_type = event.get("event", event.get("message_type", ""))
                if event_type in ("incident.triggered", "trigger"):
                    handle_triggered(event)
                elif event_type in ("incident.resolved", "resolve"):
                    handle_resolved(event)
        except Exception as e:
            log.error(f"Error processing webhook: {e}", exc_info=True)
            self.send_response(500)
            self.end_headers()
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}')

    def log_message(self, fmt, *args):
        log.info(f"{self.address_string()} - {fmt % args}")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    log.info(f"Starting incident bot on :{port}")
    HTTPServer(("", port), Handler).serve_forever()
