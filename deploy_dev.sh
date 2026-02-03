#!/bin/bash

# Deploy dev version = base deploy + dev-only skills
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  Claude Base Deployment (DEV)"
echo "=========================================="
echo ""

# ----------------------------------------
# 1. Run base deploy.sh with --clean (dev default)
# ----------------------------------------
echo "[*] Running base deploy.sh --clean..."
"$SCRIPT_DIR/deploy.sh" --clean

# ----------------------------------------
# 2. Deploy dev-only skills (skill-creator, mcp-builder)
# ----------------------------------------
echo ""
echo "[*] Deploying dev-only skills..."

TARGET_SKILLS="$HOME/.claude/skills"
SOURCE_SKILLS="$SCRIPT_DIR/skills"

# Deploy skill-creator if exists
if [ -d "$SOURCE_SKILLS/skill-creator" ]; then
    rsync -av --exclude='.git' --exclude='.DS_Store' \
        "$SOURCE_SKILLS/skill-creator/" "$TARGET_SKILLS/skill-creator/"
    echo "[+] skill-creator deployed"
fi

# Deploy mcp-builder if exists
if [ -d "$SOURCE_SKILLS/mcp-builder" ]; then
    rsync -av --exclude='.git' --exclude='.DS_Store' \
        "$SOURCE_SKILLS/mcp-builder/" "$TARGET_SKILLS/mcp-builder/"
    echo "[+] mcp-builder deployed"
fi

echo ""
echo "=========================================="
echo "  DEV Deployment Complete"
echo "=========================================="
echo ""
