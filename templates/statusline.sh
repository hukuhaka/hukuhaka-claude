#!/bin/bash
# Claude Code statusline — context, cost, model

read -r DATA

MODEL=$(echo "$DATA" | jq -r '.model.display_name // "?"')
CTX_PCT=$(echo "$DATA" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$DATA" | jq -r '.cost.total_cost_usd // 0')
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Colors
RESET="\033[0m"
DIM="\033[2m"
BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
BLUE="\033[34m"

# Context color based on usage
if [ "$CTX_PCT" -lt 50 ]; then
  CTX_COLOR="$GREEN"
elif [ "$CTX_PCT" -lt 75 ]; then
  CTX_COLOR="$YELLOW"
else
  CTX_COLOR="$RED"
fi

# Progress bar (10 chars)
BAR_LEN=10
FILLED=$((CTX_PCT * BAR_LEN / 100))
EMPTY=$((BAR_LEN - FILLED))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

# Format cost
COST_FMT=$(printf "%.2f" "$COST")

# Output
# Git branch segment
GIT_SEG=""
if [ -n "$BRANCH" ]; then
  GIT_SEG=" ${DIM}│${RESET} ${BLUE} ${BRANCH}${RESET}"
fi

# Output
printf "${DIM}│${RESET} ${CYAN}${BOLD}${MODEL}${RESET} ${DIM}│${RESET} ${CTX_COLOR}${BAR} ${CTX_PCT}%%${RESET} ${DIM}│${RESET} ${MAGENTA}\$${COST_FMT}${RESET}${GIT_SEG} ${DIM}│${RESET}"
