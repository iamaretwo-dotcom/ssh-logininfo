#!/usr/bin/env bash
# ssh-logininfo/sysinfo.sh — system overview on SSH login
# https://github.com/iamaretwo-dotcom/ssh-logininfo

set -euo pipefail

# Colors
R='\033[0;31m' G='\033[0;32m' Y='\033[0;33m' C='\033[0;36m' B='\033[1m' D='\033[0;90m' N='\033[0m'

if [[ "${1:-}" == "--no-color" ]]; then
    R='' G='' Y='' C='' B='' D='' N=''
fi

divider="${D}$(printf '%.0s─' {1..56})${N}"

# ── System ───────────────────────────────────────────────
hostname=$(hostname -f 2>/dev/null || hostname)
os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)
uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //' || uptime | sed 's/.*up //' | sed 's/,.*load.*//')
load=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
cores=$(nproc 2>/dev/null || echo "?")
mem_used=$(free -h 2>/dev/null | awk '/^Mem:/{print $3}')
mem_total=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}')
mem_pct=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
disk_used=$(df -h / 2>/dev/null | awk 'NR==2{print $3}')
disk_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')
disk_pct=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,""); print $5}')
ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "n/a")

# color thresholds
color_pct() { local p=$1; if (( p >= 90 )); then echo -e "${R}${p}%${N}"; elif (( p >= 70 )); then echo -e "${Y}${p}%${N}"; else echo -e "${G}${p}%${N}"; fi; }

echo ""
echo -e "${divider}"
echo -e " ${B}${C}${hostname}${N}"
echo -e "${divider}"
printf " ${B}OS:${N} %-22s ${B}Uptime:${N} %s\n" "$os" "$uptime_str"
printf " ${B}CPU:${N} %-2s cores, load %-8s ${B}Mem:${N} %s/%s (%b)\n" "$cores" "$load" "$mem_used" "$mem_total" "$(color_pct "$mem_pct")"
printf " ${B}Disk:${N} %s/%s (%b)          ${B}IP:${N} %s\n" "$disk_used" "$disk_total" "$(color_pct "$disk_pct")" "$ip_addr"

# ── Web Services ─────────────────────────────────────────
echo -e ""
echo -e "${divider}"
echo -e " ${B}${C}Web Services${N}"
echo -e "${divider}"

found_any=false
declare -A seen_ports=()

while IFS= read -r line; do
    port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)

    # Skip non-web ports
    case "$port" in
        22|53|3306|33060|8125|4317) continue ;;
    esac

    # Deduplicate IPv4/IPv6 entries for the same port
    [[ -n "${seen_ports[$port]:-}" ]] && continue
    seen_ports[$port]=1

    pid_info=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' 2>/dev/null || true)
    pid_num=$(echo "$line" | grep -oP 'pid=\K[0-9]+' 2>/dev/null || true)

    # If ss didn't show process info (no root), try lsof or /proc
    if [[ -z "$pid_info" && -n "$port" ]]; then
        pid_num=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1 || true)
        if [[ -z "$pid_num" ]]; then
            pid_num=$(lsof -ti :"$port" 2>/dev/null | head -1 || true)
        fi
        if [[ -n "$pid_num" ]]; then
            pid_info=$(ps -p "$pid_num" -o comm= 2>/dev/null || echo "unknown")
        fi
    fi

    printf " ${G}:%-5s${N}  %-14s  ${D}pid %s${N}\n" "$port" "${pid_info:-unknown}" "${pid_num:-?}"
    found_any=true
done < <(ss -tlnp 2>/dev/null | tail -n +2 | sort -t: -k2 -n)

if [[ "$found_any" == false ]]; then
    echo -e " ${D}No web services detected${N}"
fi

# ── Recent Logins ────────────────────────────────────────
echo -e ""
echo -e "${divider}"
echo -e " ${B}${C}Recent Logins${N}"
echo -e "${divider}"

last -5 -w 2>/dev/null | head -5 | while IFS= read -r line; do
    [[ -z "$line" || "$line" == wtmp* ]] && continue
    printf " ${D}%s${N}\n" "$line"
done

# ── Security ─────────────────────────────────────────────
echo -e ""
echo -e "${divider}"
echo -e " ${B}${C}Security${N}"
echo -e "${divider}"

# Failed SSH attempts (last 24h)
failed_count=0
if command -v journalctl &>/dev/null; then
    failed_count=$(journalctl _SYSTEMD_UNIT=ssh.service --since "24 hours ago" --no-pager 2>/dev/null \
        | grep -ciE "failed|invalid user" || true)
    failed_count=${failed_count:-0}
elif [[ -r /var/log/auth.log ]]; then
    failed_count=$(grep -ciE "failed|invalid user" /var/log/auth.log 2>/dev/null || true)
    failed_count=${failed_count:-0}
fi

if (( failed_count > 20 )); then
    printf " ${B}Failed SSH (24h):${N} ${R}%s attempts${N}\n" "$failed_count"
elif (( failed_count > 0 )); then
    printf " ${B}Failed SSH (24h):${N} ${Y}%s attempts${N}\n" "$failed_count"
else
    printf " ${B}Failed SSH (24h):${N} ${G}%s attempts${N}\n" "$failed_count"
fi

echo -e " ${D}View details:${N} journalctl _SYSTEMD_UNIT=ssh.service --since '24h ago' | grep -i 'failed\\|invalid'"
echo -e " ${D}            ${N} grep -i 'failed\\|invalid' /var/log/auth.log | tail -20"

# Pending updates
if command -v apt &>/dev/null; then
    updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)
    if (( updates > 0 )); then
        printf " ${B}Pending updates:${N} ${Y}%s packages${N}\n" "$updates"
    else
        printf " ${B}Pending updates:${N} ${G}up to date${N}\n"
    fi
elif command -v dnf &>/dev/null; then
    updates=$(dnf check-update --quiet 2>/dev/null | grep -c '.' || echo 0)
    if (( updates > 0 )); then
        printf " ${B}Pending updates:${N} ${Y}%s packages${N}\n" "$updates"
    else
        printf " ${B}Pending updates:${N} ${G}up to date${N}\n"
    fi
fi

# Docker containers (if docker is available)
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    running=$(docker ps -q 2>/dev/null | wc -l)
    total=$(docker ps -aq 2>/dev/null | wc -l)
    printf " ${B}Docker:${N} %s running / %s total\n" "$running" "$total"
fi

echo -e "${divider}"
echo ""
