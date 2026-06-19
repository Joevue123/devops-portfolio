#!/usr/bin/env bash
# Weekly cost report posted to Slack via Kubecost API
set -euo pipefail

KUBECOST_URL="${KUBECOST_URL:-http://localhost:9090}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:?set SLACK_WEBHOOK}"
WINDOW="${WINDOW:-lastweek}"

echo "==> Fetching cost allocation for window: ${WINDOW}"

# Fetch per-namespace cost breakdown
COST_DATA=$(curl -sf "${KUBECOST_URL}/model/allocation" \
  --data-urlencode "window=${WINDOW}" \
  --data-urlencode "aggregate=namespace" \
  --data-urlencode "accumulate=true" \
  --data-urlencode "includeIdle=true" | jq -r '
  .data[0] | to_entries | sort_by(-.value.totalCost) |
  map("\(.key): $\(.value.totalCost | . * 100 | round / 100)") | .[]
')

TOTAL=$(curl -sf "${KUBECOST_URL}/model/allocation" \
  --data-urlencode "window=${WINDOW}" \
  --data-urlencode "aggregate=cluster" \
  --data-urlencode "accumulate=true" | jq -r '.data[0][""].totalCost | . * 100 | round / 100')

# Fetch rightsizing summary
SAVINGS=$(curl -sf "${KUBECOST_URL}/savings/requestSizingV2" | \
  jq -r '[.[] | .monthlySavings] | add // 0 | . * 100 | round / 100')

SLACK_MSG=$(cat <<EOF
{
  "text": "*Weekly Kubernetes Cost Report — ${WINDOW}*",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Total Cluster Cost:* \$${TOTAL}\n*Rightsizing Opportunity:* \$${SAVINGS}/mo"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*By Namespace:*\n\`\`\`${COST_DATA}\`\`\`"
      }
    }
  ]
}
EOF
)

curl -sf -X POST "${SLACK_WEBHOOK}" \
  -H 'Content-type: application/json' \
  --data "${SLACK_MSG}"

echo "==> Report sent to Slack"
