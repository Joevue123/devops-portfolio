#!/usr/bin/env bash
set -euo pipefail

# Load config from same directory if present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/config.env" ]] && source "${SCRIPT_DIR}/config.env"

# Defaults (override in config.env)
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEM_THRESHOLD="${MEM_THRESHOLD:-85}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.0}"
LOG_FILE="${LOG_FILE:-/var/log/system-health.log}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
HOSTNAME="${HOSTNAME:-$(hostname -f)}"

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')
ALERTS=()
REPORT=()

log() { echo "[${TIMESTAMP}] $*" | tee -a "${LOG_FILE}"; }

send_slack_alert() {
    local message="$1"
    [[ -z "${SLACK_WEBHOOK}" ]] && return 0
    curl -s -X POST "${SLACK_WEBHOOK}" \
        -H 'Content-Type: application/json' \
        -d "{\"text\": \":warning: *${HOSTNAME}* — ${message}\"}" \
        > /dev/null
}

send_email_alert() {
    local subject="$1" body="$2"
    [[ -z "${ALERT_EMAIL}" ]] && return 0
    echo "${body}" | mail -s "[ALERT] ${subject} on ${HOSTNAME}" "${ALERT_EMAIL}"
}

check_cpu() {
    local cpu_idle cpu_usage
    cpu_idle=$(vmstat 1 2 | tail -1 | awk '{print $15}')
    cpu_usage=$((100 - cpu_idle))
    REPORT+=("CPU: ${cpu_usage}%")

    if (( cpu_usage >= CPU_THRESHOLD )); then
        local msg="CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
        ALERTS+=("${msg}")
        log "ALERT: ${msg}"

        log "Top 5 CPU consumers:"
        ps aux --sort=-%cpu | awk 'NR==1 || NR<=6 {print}' | while read -r line; do
            log "  ${line}"
        done
    else
        log "OK: CPU usage at ${cpu_usage}%"
    fi
}

check_memory() {
    local mem_total mem_available mem_used mem_pct
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    mem_used=$(( mem_total - mem_available ))
    mem_pct=$(( mem_used * 100 / mem_total ))
    REPORT+=("Memory: ${mem_pct}% ($(( mem_used / 1024 ))MB / $(( mem_total / 1024 ))MB)")

    if (( mem_pct >= MEM_THRESHOLD )); then
        local msg="Memory usage is ${mem_pct}% (threshold: ${MEM_THRESHOLD}%)"
        ALERTS+=("${msg}")
        log "ALERT: ${msg}"

        log "Top 5 memory consumers:"
        ps aux --sort=-%mem | awk 'NR==1 || NR<=6 {print}' | while read -r line; do
            log "  ${line}"
        done
    else
        log "OK: Memory usage at ${mem_pct}%"
    fi
}

check_disk() {
    local alert_triggered=false
    while IFS= read -r line; do
        local usage mountpoint
        usage=$(echo "${line}" | awk '{print $5}' | tr -d '%')
        mountpoint=$(echo "${line}" | awk '{print $6}')

        REPORT+=("Disk ${mountpoint}: ${usage}%")

        if (( usage >= DISK_THRESHOLD )); then
            local msg="Disk ${mountpoint} is ${usage}% full (threshold: ${DISK_THRESHOLD}%)"
            ALERTS+=("${msg}")
            log "ALERT: ${msg}"
            alert_triggered=true
        else
            log "OK: Disk ${mountpoint} at ${usage}%"
        fi
    done < <(df -h --output=pcent,target | tail -n +2 | grep -v '^[[:space:]]*$')
}

check_load() {
    local load_1min load_5min load_15min cpu_count
    read -r load_1min load_5min load_15min _ < /proc/loadavg
    cpu_count=$(nproc)
    REPORT+=("Load avg: ${load_1min} ${load_5min} ${load_15min} (${cpu_count} cores)")

    if (( $(echo "${load_1min} >= ${LOAD_THRESHOLD}" | bc -l) )); then
        local msg="1-min load average is ${load_1min} (threshold: ${LOAD_THRESHOLD}, cores: ${cpu_count})"
        ALERTS+=("${msg}")
        log "ALERT: ${msg}"
    else
        log "OK: Load average at ${load_1min}"
    fi
}

check_processes() {
    local zombie_count
    zombie_count=$(ps aux | awk '$8=="Z" {count++} END {print count+0}')
    REPORT+=("Zombie processes: ${zombie_count}")

    if (( zombie_count > 5 )); then
        local msg="High zombie process count: ${zombie_count}"
        ALERTS+=("${msg}")
        log "ALERT: ${msg}"
    fi
}

check_network() {
    if command -v ss &>/dev/null; then
        local established_conns
        established_conns=$(ss -tn state established | wc -l)
        REPORT+=("TCP connections (established): ${established_conns}")
        log "OK: ${established_conns} established TCP connections"
    fi
}

send_alerts() {
    [[ ${#ALERTS[@]} -eq 0 ]] && return 0

    local summary
    summary="$(IFS=$'\n'; echo "${ALERTS[*]}")"
    local full_report
    full_report="$(IFS=$'\n'; echo "${REPORT[*]}")"

    send_slack_alert "$(echo "${ALERTS[@]}" | tr '\n' ' | ')"
    send_email_alert "System health alerts" \
        "Alerts on ${HOSTNAME} at ${TIMESTAMP}:

${summary}

Full system report:
${full_report}"

    return ${#ALERTS[@]}
}

main() {
    log "=== System health check started on ${HOSTNAME} ==="
    check_cpu
    check_memory
    check_disk
    check_load
    check_processes
    check_network

    log "--- Summary ---"
    for item in "${REPORT[@]}"; do
        log "  ${item}"
    done

    if ! send_alerts; then
        log "=== ${#ALERTS[@]} alert(s) sent ==="
        exit 1
    fi

    log "=== All checks passed ==="
}

main "$@"
