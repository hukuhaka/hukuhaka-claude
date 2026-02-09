#!/bin/bash
set -euo pipefail

# ----------------------------------------
# hukuhaka-claude updater
# Called by: huku-update alias
#
# Usage:
#   bash update.sh           # Interactive update (prompts on dirty tree)
#   bash update.sh --force   # Discard local changes without prompting
# ----------------------------------------

cd "$(dirname "${BASH_SOURCE[0]}")"

# ----------------------------------------
# Parse flags
# ----------------------------------------
FORCE=false
PASSTHROUGH_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
    esac
done

echo "[*] Updating hukuhaka-claude..."

# ----------------------------------------
# 1. Handle dirty working tree
# ----------------------------------------
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "[!] Local changes detected:"
    git diff --stat HEAD
    echo ""

    if [ "$FORCE" = true ]; then
        echo "[*] --force: Discarding local changes..."
        git checkout -- .
    elif [ -t 0 ]; then
        echo "Options:"
        echo "  1) Stash changes and continue"
        echo "  2) Discard changes and continue"
        echo "  3) Cancel update"
        echo ""
        read -p "Choose [1/2/3]: " -n 1 -r CHOICE
        echo ""

        case "$CHOICE" in
            1)
                git stash push -m "huku-update: auto-stash $(date +%Y%m%d-%H%M%S)"
                echo "[+] Changes stashed. Restore later with: git stash pop"
                ;;
            2)
                git checkout -- .
                echo "[+] Local changes discarded"
                ;;
            *)
                echo "[!] Update cancelled."
                exit 0
                ;;
        esac
    else
        echo "[!] Non-interactive mode with local changes. Cannot proceed."
        echo "    To discard changes: bash update.sh --force"
        echo "    To stash manually:  cd $(pwd) && git stash"
        exit 1
    fi
fi

# ----------------------------------------
# 2. Pull latest
# ----------------------------------------
if git pull --ff-only 2>/dev/null; then
    echo "[+] Source updated"
else
    echo "[!] Fast-forward pull failed (upstream history diverged)."

    if [ "$FORCE" = true ]; then
        echo "[*] --force: Resetting to origin/main..."
        git fetch origin main
        git reset --hard origin/main
        echo "[+] Source reset to origin/main"
    elif [ -t 0 ]; then
        echo ""
        echo "Options:"
        echo "  1) Reset to origin/main (discard local commits)"
        echo "  2) Cancel update"
        echo ""
        read -p "Choose [1/2]: " -n 1 -r CHOICE
        echo ""

        case "$CHOICE" in
            1)
                git fetch origin main
                git reset --hard origin/main
                echo "[+] Source reset to origin/main"
                ;;
            *)
                echo "[!] Update cancelled."
                exit 0
                ;;
        esac
    else
        echo "[!] Non-interactive mode. Cannot resolve diverged history."
        echo "    To force reset: bash update.sh --force"
        exit 1
    fi
fi

# ----------------------------------------
# 3. Run deploy with latest code
# ----------------------------------------
exec ./deploy.sh "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
