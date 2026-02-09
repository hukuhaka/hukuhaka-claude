#!/bin/bash
set -euo pipefail

cleanup_on_error() {
    echo ""
    echo "[!] Deployment failed. Your previous installation should still work."
    echo "    To retry: ./deploy.sh"
    echo "    To clean install: ./deploy.sh --clean --yes"
}
trap cleanup_on_error ERR

# ----------------------------------------
# Parse command line options
# ----------------------------------------
DRY_RUN=false
YES_MODE=false
CLEAN_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --yes|-y)
            YES_MODE=true
            shift
            ;;
        --clean|clean)
            CLEAN_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# ----------------------------------------
# Check required tools
# ----------------------------------------
check_required_tools() {
    local missing=()
    for tool in curl; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done

    # jq or python3 required for JSON manipulation
    if ! command -v jq &>/dev/null && ! command -v python3 &>/dev/null; then
        missing+=("jq or python3")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "[!] Missing required tools: ${missing[*]}"
        echo "    Install with:"
        echo "      macOS: brew install ${missing[*]}"
        echo "      Linux: apt install ${missing[*]}"
        exit 1
    fi
}

check_required_tools

# ----------------------------------------
# Validate JSON file
# ----------------------------------------
validate_json() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return 0  # File doesn't exist, will be created
    fi

    if command -v jq &>/dev/null; then
        if ! jq empty "$file" 2>/dev/null; then
            echo "[!] Invalid JSON: $file"
            echo "    Please fix the JSON syntax and try again"
            exit 1
        fi
    elif command -v python3 &>/dev/null; then
        if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
            echo "[!] Invalid JSON: $file"
            echo "    Please fix the JSON syntax and try again"
            exit 1
        fi
    fi
}

# ----------------------------------------
# Version comparison using sort -V
# ----------------------------------------
version_gte() {
    # Returns 0 if $1 >= $2
    local v1="$1"
    local v2="$2"
    [ "$v1" = "$(printf '%s\n%s' "$v1" "$v2" | sort -V | tail -n1)" ]
}

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude"
TARGET_SKILLS="$TARGET_DIR/skills"
TARGET_AGENTS="$TARGET_DIR/agents"
TARGET_PLUGINS="$TARGET_DIR/plugins"
SOURCE_SKILLS="$SCRIPT_DIR/skills"
SOURCE_AGENTS="$SCRIPT_DIR/agents"

# Marketplace info
MARKETPLACE_NAME="hukuhaka-plugin"
MARKETPLACE_SOURCE="$SCRIPT_DIR/plugins/$MARKETPLACE_NAME"
MARKETPLACE_TARGET="$TARGET_PLUGINS/$MARKETPLACE_NAME"
PLUGIN_NAME="project-mapper"
SETTINGS_FILE="$TARGET_DIR/settings.json"

# ----------------------------------------
# 0. Handle --clean option
# ----------------------------------------
if [ "$CLEAN_MODE" = true ]; then
    echo "=========================================="
    echo "  Clean Install Mode"
    echo "=========================================="
    echo ""
    echo "[!] This will remove all deployed files:"
    echo "    - $TARGET_SKILLS"
    echo "    - $TARGET_AGENTS"
    echo "    - $MARKETPLACE_TARGET"
    echo "    - Plugin settings from $SETTINGS_FILE"
    echo ""
    if [ "$YES_MODE" = true ]; then
        REPLY="y"
    else
        read -p "Continue? [y/N] " -n 1 -r
        echo ""
    fi

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "[*] Cleaning previous installation..."

        # Remove deployed directories
        rm -rf "$TARGET_SKILLS"
        echo "[x] Removed: $TARGET_SKILLS"

        rm -rf "$TARGET_AGENTS"
        echo "[x] Removed: $TARGET_AGENTS"

        rm -rf "$MARKETPLACE_TARGET"
        echo "[x] Removed: $MARKETPLACE_TARGET"

        # Clean settings.json
        if [ -f "$SETTINGS_FILE" ]; then
            if command -v jq &> /dev/null; then
                jq 'del(.extraKnownMarketplaces["hukuhaka-plugin"]) | del(.enabledPlugins["project-mapper@hukuhaka-plugin"])' \
                    "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
                echo "[x] Cleaned: settings.json"
            elif command -v python3 &> /dev/null; then
                python3 << EOF
import json
try:
    with open("$SETTINGS_FILE", 'r') as f:
        settings = json.load(f)
    settings.get('extraKnownMarketplaces', {}).pop('hukuhaka-plugin', None)
    settings.get('enabledPlugins', {}).pop('project-mapper@hukuhaka-plugin', None)
    with open("$SETTINGS_FILE", 'w') as f:
        json.dump(settings, f, indent=2)
    print('[x] Cleaned: settings.json')
except Exception as e:
    print(f'[!] Failed to clean settings.json: {e}')
EOF
            fi
        fi

        echo ""
        echo "[+] Clean complete. Proceeding with fresh install..."
        echo ""
    else
        echo "[!] Cancelled."
        exit 0
    fi
fi

echo "=========================================="
if [ "$DRY_RUN" = true ]; then
    echo "  Claude Base Deployment (DRY RUN)"
else
    echo "  Claude Base Deployment"
fi
echo "=========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "[*] DRY RUN MODE - No changes will be made"
    echo ""
fi

# ----------------------------------------
# 1. Check MCP code-search installation
# ----------------------------------------
echo "[*] Checking MCP code-search..."

MCP_CONFIG="$HOME/.claude.json"
MCP_INSTALLED=false

if [ -f "$MCP_CONFIG" ]; then
    if grep -q "code-search" "$MCP_CONFIG" 2>/dev/null; then
        MCP_INSTALLED=true
        echo "[+] MCP code-search: Installed"
    fi
fi

if [ "$MCP_INSTALLED" = false ]; then
    echo "[!] MCP code-search: Not found"
    echo "[*] Installing MCP code-search..."
    echo ""
    echo "    NOTE: Requires HuggingFace model access approval at:"
    echo "    https://huggingface.co/google/embeddinggemma-300m"
    echo ""

    MCP_NEEDS_INSTALL=true
else
    MCP_NEEDS_INSTALL=false
fi

# ----------------------------------------
# 1.5. Check HuggingFace token (required for MCP code-search)
# ----------------------------------------
echo "[*] Checking HuggingFace token..."

HF_TOKEN_PATH="$HOME/.cache/huggingface/token"
LOCAL_TOKEN_FILE="$SCRIPT_DIR/token.txt"

# Check order: local token.txt > cached token > prompt
if [ -f "$LOCAL_TOKEN_FILE" ]; then
    HF_TOKEN=$(grep '^HF_TOKEN=' "$LOCAL_TOKEN_FILE" | head -n1 | sed 's/^HF_TOKEN="\{0,1\}\(.*\)"\{0,1\}$/\1/')
    echo "[+] HuggingFace token: Found (token.txt)"
elif [ -f "$HF_TOKEN_PATH" ]; then
    HF_TOKEN=$(cat "$HF_TOKEN_PATH")
    echo "[+] HuggingFace token: Found (cached)"
else
    echo "[!] HuggingFace token: Not found"
    echo "    Get token at: https://huggingface.co/settings/tokens"
    if [ -t 0 ]; then
        read -sp "    Enter HuggingFace token: " HF_TOKEN
        echo ""
        if [ -n "$HF_TOKEN" ]; then
            mkdir -p "$(dirname "$HF_TOKEN_PATH")"
            echo "$HF_TOKEN" > "$HF_TOKEN_PATH"
            chmod 600 "$HF_TOKEN_PATH"
            echo "[+] HuggingFace token: Saved"
        fi
    else
        echo "[!] Non-interactive mode. Set HF_TOKEN env var or create token.txt"
        echo "    Continuing without HuggingFace token..."
    fi
fi

if [ -n "${HF_TOKEN:-}" ]; then
    export HF_TOKEN
    export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
fi

# ----------------------------------------
# 1.6. Install MCP code-search if needed
# ----------------------------------------
if [ "$MCP_NEEDS_INSTALL" = true ]; then
    echo "[*] Step 1: Installing claude-context-local..."
    curl -fsSL https://raw.githubusercontent.com/FarhanAliRaza/claude-context-local/main/scripts/install.sh | bash

    echo "[*] Step 2: Registering MCP server with Claude..."
    if command -v claude &> /dev/null; then
        claude mcp add code-search --scope user -- uv run --directory ~/.local/share/claude-context-local python mcp_server/server.py
        echo "[+] MCP code-search: Registered with Claude"
    else
        echo "[!] 'claude' command not found. Register manually:"
        echo "    claude mcp add code-search --scope user -- uv run --directory ~/.local/share/claude-context-local python mcp_server/server.py"
    fi

    if [ -f "$MCP_CONFIG" ] && grep -q "code-search" "$MCP_CONFIG" 2>/dev/null; then
        MCP_INSTALLED=true
        echo "[+] MCP code-search: Installation complete"
    else
        echo "[!] MCP code-search: Installation may have failed"
        echo "    Step 1: curl -fsSL https://raw.githubusercontent.com/FarhanAliRaza/claude-context-local/main/scripts/install.sh | bash"
        echo "    Step 2: claude mcp add code-search --scope user -- uv run --directory ~/.local/share/claude-context-local python mcp_server/server.py"
    fi
fi

# ----------------------------------------
# 2. Deploy CLAUDE.md
# ----------------------------------------
echo "[*] Deploying CLAUDE.md to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

if [ -f "$SCRIPT_DIR/CLAUDE.md" ]; then
    cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    echo "[+] Done: CLAUDE.md"
else
    echo "[!] Warning: CLAUDE.md not found"
fi

# ----------------------------------------
# 3. Deploy standalone skills
# ----------------------------------------
echo "[*] Deploying standalone skills to $TARGET_SKILLS..."

mkdir -p "$TARGET_SKILLS"

# Check codex prerequisites
CODEX_AVAILABLE=true
CODEX_MISSING=""
CODEX_MIN_VERSION="0.93"

if ! command -v npm &> /dev/null; then
    CODEX_AVAILABLE=false
    CODEX_MISSING="npm"
fi

if ! command -v codex &> /dev/null; then
    CODEX_AVAILABLE=false
    if [ -n "$CODEX_MISSING" ]; then
        CODEX_MISSING="$CODEX_MISSING, codex CLI"
    else
        CODEX_MISSING="codex CLI"
    fi
else
    # Check codex version (requires v0.93+ for native review command)
    CODEX_VERSION=$(codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [ -n "$CODEX_VERSION" ]; then
        if ! version_gte "$CODEX_VERSION" "$CODEX_MIN_VERSION"; then
            echo "[!] Codex version $CODEX_VERSION < $CODEX_MIN_VERSION (required)"
            echo "[*] Upgrading codex..."
            npm update -g @openai/codex 2>&1 | grep -E "(changed|up to date)" || true

            # Re-check version after upgrade
            CODEX_VERSION=$(codex --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

            if ! version_gte "$CODEX_VERSION" "$CODEX_MIN_VERSION"; then
                CODEX_AVAILABLE=false
                CODEX_MISSING="codex v$CODEX_MIN_VERSION+ (current: $CODEX_VERSION)"
            else
                echo "[+] Codex upgraded to v$CODEX_VERSION"
            fi
        else
            echo "[+] Codex v$CODEX_VERSION (>= $CODEX_MIN_VERSION)"
        fi
    fi
fi

# Use bash array for rsync excludes (avoids eval injection risk)
SKILL_EXCLUDES=(
    --exclude='.git'
    --exclude='.DS_Store'
    --exclude='skill-creator'
    --exclude='mcp-builder'
)

if [ "$CODEX_AVAILABLE" = false ]; then
    SKILL_EXCLUDES+=(--exclude='codex-coworker')
    echo "[!] Skipping codex-coworker (missing: $CODEX_MISSING)"
    echo "    Install: npm install -g @openai/codex"
fi

if [ -d "$SOURCE_SKILLS" ]; then
    if command -v rsync &> /dev/null; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would rsync skills: $SOURCE_SKILLS -> $TARGET_SKILLS"
            rsync -av --delete --dry-run "${SKILL_EXCLUDES[@]}" "$SOURCE_SKILLS"/ "$TARGET_SKILLS/"
        else
            rsync -av --delete "${SKILL_EXCLUDES[@]}" "$SOURCE_SKILLS"/ "$TARGET_SKILLS/"
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would copy skills: $SOURCE_SKILLS -> $TARGET_SKILLS"
        else
            rm -rf "$TARGET_SKILLS"
            mkdir -p "$TARGET_SKILLS"
            cp -r "$SOURCE_SKILLS"/* "$TARGET_SKILLS"/ 2>/dev/null || true
            rm -rf "$TARGET_SKILLS/skill-creator" "$TARGET_SKILLS/mcp-builder" 2>/dev/null || true
            if [ "$CODEX_AVAILABLE" = false ]; then
                rm -rf "$TARGET_SKILLS/codex-coworker" 2>/dev/null || true
            fi
        fi
    fi
    echo "[+] Done: skills/ deployed"
else
    echo "[~] Skipped: No standalone skills found"
fi

# ----------------------------------------
# 4. Deploy standalone agents
# ----------------------------------------
echo "[*] Deploying standalone agents to $TARGET_AGENTS..."

mkdir -p "$TARGET_AGENTS"

if [ -d "$SOURCE_AGENTS" ] && [ "$(ls -A "$SOURCE_AGENTS" 2>/dev/null)" ]; then
    if command -v rsync &> /dev/null; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would rsync agents: $SOURCE_AGENTS -> $TARGET_AGENTS"
            rsync -av --delete --dry-run --exclude='.git' --exclude='.DS_Store' "$SOURCE_AGENTS"/ "$TARGET_AGENTS/"
        else
            rsync -av --delete --exclude='.git' --exclude='.DS_Store' "$SOURCE_AGENTS"/ "$TARGET_AGENTS/"
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would copy agents: $SOURCE_AGENTS -> $TARGET_AGENTS"
        else
            rm -rf "$TARGET_AGENTS"
            mkdir -p "$TARGET_AGENTS"
            cp -r "$SOURCE_AGENTS"/* "$TARGET_AGENTS"/ 2>/dev/null || true
        fi
    fi
    echo "[+] Done: agents/ deployed"
else
    echo "[~] Skipped: No standalone agents found"
fi

# ----------------------------------------
# 5. Read plugin version from plugin.json (no source modification)
# ----------------------------------------
PLUGIN_JSON="$MARKETPLACE_SOURCE/$PLUGIN_NAME/.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
    if command -v jq &> /dev/null; then
        PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_JSON")
    elif command -v python3 &> /dev/null; then
        PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON'))['version'])")
    else
        PLUGIN_VERSION="unknown"
    fi
    echo "[*] Plugin version: $PLUGIN_VERSION"
else
    echo "[~] No plugin.json found"
fi

# ----------------------------------------
# 6. Deploy plugin (Directory source method)
# ----------------------------------------
echo "[*] Deploying $MARKETPLACE_NAME marketplace..."

mkdir -p "$TARGET_PLUGINS"

if [ -d "$MARKETPLACE_SOURCE" ]; then
    # Copy marketplace to ~/.claude/plugins/
    if command -v rsync &> /dev/null; then
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would rsync marketplace: $MARKETPLACE_SOURCE -> $MARKETPLACE_TARGET"
            rsync -av --delete --dry-run --exclude='.git' --exclude='.DS_Store' \
                --exclude='*.backup' "$MARKETPLACE_SOURCE"/ "$MARKETPLACE_TARGET/"
        else
            rsync -av --delete --exclude='.git' --exclude='.DS_Store' \
                --exclude='*.backup' "$MARKETPLACE_SOURCE"/ "$MARKETPLACE_TARGET/"
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] Would copy marketplace: $MARKETPLACE_SOURCE -> $MARKETPLACE_TARGET"
        else
            rm -rf "$MARKETPLACE_TARGET"
            mkdir -p "$MARKETPLACE_TARGET"
            cp -r "$MARKETPLACE_SOURCE"/* "$MARKETPLACE_TARGET"/ 2>/dev/null || true
        fi
    fi
    echo "[+] Marketplace copied to: $MARKETPLACE_TARGET"

    # Update settings.json with directory marketplace
    echo "[*] Updating settings.json..."

    # Validate existing settings.json before modification
    if [ -f "$SETTINGS_FILE" ]; then
        validate_json "$SETTINGS_FILE"
    else
        echo '{}' > "$SETTINGS_FILE"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would update settings.json with marketplace config"
    # Use jq if available, otherwise use python
    elif command -v jq &> /dev/null; then
        # Create temp file with updated settings
        jq --arg path "$MARKETPLACE_TARGET" '
        .extraKnownMarketplaces["hukuhaka-plugin"] = {
            "source": {
                "source": "directory",
                "path": $path
            }
        } |
        .enabledPlugins["project-mapper@hukuhaka-plugin"] = true
        ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
        echo "[+] settings.json updated (jq)"
    elif command -v python3 &> /dev/null; then
        python3 << EOF
import json
import os

settings_file = "$SETTINGS_FILE"
marketplace_target = "$MARKETPLACE_TARGET"

try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# Add extraKnownMarketplaces
if 'extraKnownMarketplaces' not in settings:
    settings['extraKnownMarketplaces'] = {}

settings['extraKnownMarketplaces']['hukuhaka-plugin'] = {
    'source': {
        'source': 'directory',
        'path': marketplace_target
    }
}

# Add enabledPlugins
if 'enabledPlugins' not in settings:
    settings['enabledPlugins'] = {}

settings['enabledPlugins']['project-mapper@hukuhaka-plugin'] = True

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print('[+] settings.json updated (python3)')
EOF
    else
        echo "[!] Warning: jq or python3 required for settings.json update"
        echo "    Install jq: brew install jq (macOS) or apt install jq (Linux)"
        echo ""
        echo "    Manual setup required. Add to ~/.claude/settings.json:"
        echo '    {'
        echo '      "extraKnownMarketplaces": {'
        echo '        "hukuhaka-plugin": {'
        echo '          "source": {'
        echo '            "source": "directory",'
        echo "            \"path\": \"$MARKETPLACE_TARGET\""
        echo '          }'
        echo '        }'
        echo '      },'
        echo '      "enabledPlugins": {'
        echo '        "project-mapper@hukuhaka-plugin": true'
        echo '      }'
        echo '    }'
    fi
else
    echo "[!] Warning: Marketplace source not found at $MARKETPLACE_SOURCE"
fi

# ----------------------------------------
# 7. Clear Claude Code plugin cache
# ----------------------------------------
PLUGIN_CACHE="$HOME/.claude/plugins/cache/$MARKETPLACE_NAME"

if [ -d "$PLUGIN_CACHE" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would remove plugin cache: $PLUGIN_CACHE"
    else
        rm -rf "$PLUGIN_CACHE"
        echo "[+] Cleared plugin cache: $PLUGIN_CACHE"
    fi
else
    echo "[~] No plugin cache to clear"
fi

# ----------------------------------------
# 8. Remove old marketplace config (cleanup)
# ----------------------------------------
echo "[*] Cleaning up old configurations..."

# Remove old alias if exists
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    if [ "$DRY_RUN" = true ]; then
        if grep -q "# claude-base:alias" "$SHELL_RC" 2>/dev/null; then
            echo "[DRY-RUN] Would remove old claude-base alias"
        fi
        if grep -q "alias huku-update=" "$SHELL_RC" 2>/dev/null && ! grep -q "update.sh" "$SHELL_RC" 2>/dev/null; then
            echo "[DRY-RUN] Would migrate huku-update alias to update.sh"
        fi
    else
        if grep -q "# claude-base:alias" "$SHELL_RC"; then
            # macOS sed requires '' after -i, Linux sed doesn't accept it
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/# claude-base:alias/{N;d;}' "$SHELL_RC" 2>/dev/null || true
            else
                sed -i '/# claude-base:alias/{N;d;}' "$SHELL_RC" 2>/dev/null || true
            fi
            echo "[+] Old claude-base alias removed"
        fi

        # Migrate old inline alias to update.sh
        INSTALL_DIR="$HOME/.hukuhaka-claude"
        ALIAS_LINE="alias huku-update='bash $INSTALL_DIR/update.sh'"
        if grep -q "alias huku-update=" "$SHELL_RC" 2>/dev/null && ! grep -q "update.sh" "$SHELL_RC" 2>/dev/null; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "/alias huku-update=/c\\
$ALIAS_LINE" "$SHELL_RC"
            else
                sed -i "/alias huku-update=/c\\$ALIAS_LINE" "$SHELL_RC"
            fi
            echo "[+] Migrated huku-update alias to update.sh"
        fi
    fi
fi

# ----------------------------------------
# 9. Summary
# ----------------------------------------
echo ""
echo "=========================================="
echo "  Deployment Summary"
echo "=========================================="
echo ""

# MCP Status
if [ "$MCP_INSTALLED" = true ]; then
    echo "[✓] MCP code-search: Ready"
else
    echo "[✗] MCP code-search: Not installed"
fi

# CLAUDE.md Status
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    echo "[✓] CLAUDE.md: Deployed"
else
    echo "[✗] CLAUDE.md: Failed"
fi

# Skills Status
if [ -d "$TARGET_SKILLS" ]; then
    # Count only directories containing SKILL.md (actual skills)
    SKILL_COUNT=$(find "$TARGET_SKILLS" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "[✓] Standalone Skills: $SKILL_COUNT deployed"
else
    echo "[✗] Skills: Failed"
fi

# Agents Status
if [ -d "$TARGET_AGENTS" ]; then
    AGENT_COUNT=$(find "$TARGET_AGENTS" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "[✓] Standalone Agents: $AGENT_COUNT deployed"
else
    echo "[✗] Agents: Failed"
fi

# Marketplace Status
if [ -d "$MARKETPLACE_TARGET" ]; then
    echo "[✓] Marketplace: $MARKETPLACE_NAME deployed to $MARKETPLACE_TARGET"
    echo "    Plugin: $PLUGIN_NAME enabled"
    echo "    Method: Directory source (no cache)"
else
    echo "[✗] Marketplace: Failed"
fi

echo ""
echo "=========================================="
echo ""
echo "Usage:"
echo "  /project-mapper:map analyze ."
echo "  /project-mapper:map sync ."
echo ""
echo "To update plugin, just run deploy.sh again!"
echo ""
