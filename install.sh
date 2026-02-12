#!/usr/bin/env bash
# install.sh — install sysinfo.sh as SSH login banner
# Usage: ./install.sh [--uninstall]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSINFO="${SCRIPT_DIR}/sysinfo.sh"
MARKER="# ssh-logininfo"
PROFILE="${HOME}/.profile"

if [[ "${1:-}" == "--uninstall" ]]; then
    if [[ -f "$PROFILE" ]]; then
        sed -i "/${MARKER}/d" "$PROFILE"
        echo "Removed ssh-logininfo from ${PROFILE}"
    fi
    exit 0
fi

chmod +x "$SYSINFO"

# Add to .profile if not already present
if ! grep -qF "$MARKER" "$PROFILE" 2>/dev/null; then
    echo "" >> "$PROFILE"
    echo "[[ -n \"\${SSH_CONNECTION:-}\" && -t 0 ]] && ${SYSINFO} ${MARKER}" >> "$PROFILE"
    echo "Installed: sysinfo.sh will run on SSH login."
    echo "Source: ${SYSINFO}"
else
    echo "Already installed in ${PROFILE}"
fi
