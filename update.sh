#!/bin/bash
set -euo pipefail

# ----------------------------------------
# hukuhaka-claude updater
# Called by: huku-update alias
# ----------------------------------------

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "[*] Updating hukuhaka-claude..."

# 1. Reset local changes (deploy.sh may have left artifacts)
git checkout -- . 2>/dev/null || true

# 2. Pull latest
if ! git pull --ff-only 2>/dev/null; then
    echo "[!] Fast-forward failed. Fetching and resetting..."
    git fetch origin main
    git reset --hard origin/main
fi

echo "[+] Source updated"

# 3. Run deploy with latest code
exec ./deploy.sh "$@"
