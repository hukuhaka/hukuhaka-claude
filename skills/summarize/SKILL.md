---
name: summarize
description: Execute commands with isolated context and summarized output. Use when user says "/summarize", wants to run tests, builds, scripts, or any command that produces verbose output. Delegates to result-runner agent for token-efficient execution.
---

# /summarize - Isolated Command Runner

Execute commands in isolated context, return clean summaries.

## Usage
/summarize <command>

## Examples
- `/summarize pytest` - Run tests, get pass/fail summary
- `/summarize npm run build` - Run build, get success/error report
- `/summarize python main.py` - Execute script, get output summary

## Execution

When invoked, delegate to the `result-runner` agent:

1. Use Task tool with `subagent_type: "result-runner"`
2. Pass the command from user input
3. Agent runs in Haiku, returns max 20-line summary
4. Display summary to user
