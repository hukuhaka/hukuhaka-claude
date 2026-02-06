#!/bin/bash
set -euo pipefail

# ----------------------------------------
# hukuhaka-claude installer
# Usage: curl -fsSL https://raw.githubusercontent.com/hukuhaka/hukuhaka-claude/main/install.sh | bash
# ----------------------------------------

REPO_URL="https://github.com/hukuhaka/hukuhaka-claude.git"
INSTALL_DIR="$HOME/.hukuhaka-claude"

echo "=========================================="
echo "  hukuhaka-claude installer"
echo "=========================================="
echo ""

# Check git
if ! command -v git &> /dev/null; then
    echo "[!] git is required. Install it first."
    exit 1
fi

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
    echo "[*] Updating existing installation..."
    cd "$INSTALL_DIR"
    git checkout -- . 2>/dev/null || true
    git pull --ff-only
else
    echo "[*] Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Run deploy
echo "[*] Running deploy..."
./deploy.sh "$@"

# Add alias if not exists
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

ALIAS_LINE="alias huku-update='bash $INSTALL_DIR/update.sh'"
if [ -n "$SHELL_RC" ]; then
    if grep -q "huku-update" "$SHELL_RC" 2>/dev/null; then
        # Replace existing alias (macOS/Linux sed compatible)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/alias huku-update=/c\\
$ALIAS_LINE" "$SHELL_RC"
        else
            sed -i "/alias huku-update=/c\\$ALIAS_LINE" "$SHELL_RC"
        fi
        echo "[+] Updated 'huku-update' alias in $SHELL_RC"
    else
        echo "" >> "$SHELL_RC"
        echo "# hukuhaka-claude" >> "$SHELL_RC"
        echo "$ALIAS_LINE" >> "$SHELL_RC"
        echo "[+] Added 'huku-update' alias to $SHELL_RC"
    fi
    echo "    Run: source $SHELL_RC"
fi

echo ""
echo "=========================================="
echo "  Installation complete!"
echo "=========================================="
echo ""
echo "Commands:"
echo "  huku-update    - Update and redeploy"
echo ""
