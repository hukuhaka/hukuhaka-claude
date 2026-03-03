---
name: team
description: >
  Create an agent team for collaborative problem-solving.
  Use when user asks to create a team, swarm, or group of agents
  to work together on a problem.
---

# Team Quick-Spawn

Parse `$ARGUMENTS`, create a team, spawn agents in parallel.

## Rules

- Use **TaskCreate** tool for creating tasks. NEVER use TodoWrite — it is the wrong tool
- Step 4 (Spawn Agents): emit ALL Agent tool calls in one response. Do NOT call Agent, wait for result, then call Agent again

## 1. Parse Arguments

Format: `problem description -- role1, role2, role3`

Extract from `$ARGUMENTS`:
- **Problem**: all text before `--` (e.g., `pickle error in optimize phase`)
- **Roles**: comma-separated list after `--` (e.g., `frontend, backend, infra`)

Quoted problem text is also accepted: `"problem" role1, role2` (extract text inside quotes as problem, remainder as roles).

If problem is empty, use AskUserQuestion to ask: "What problem should the team investigate?"
If roles are empty, use AskUserQuestion to ask: "What roles should the team have? (comma-separated)"
If more than 5 roles, warn the user and truncate to the first 5.

## 2. Create Team

Call TeamCreate:
- `team_name`: slugify the first 3 words of the problem (lowercase, hyphens, e.g., `pickle-error-in`)
- `description`: the full problem text

## 3. Create Tasks (REQUIRED — do NOT skip)

You MUST call the **TaskCreate** tool once per role before spawning agents. Do NOT use TodoWrite — use TaskCreate. Do NOT skip this step.

For each role, call TaskCreate:
- `subject`: `{role}: {problem}`
- `description`: `Investigate the problem from the {role} perspective. Search the codebase, run relevant commands, and report findings.`
- `activeForm`: `Investigating as {role}`

## 4. Spawn Agents

Issue ALL Agent tool calls in a **single response** (one message containing N Agent tool_use blocks). Do NOT wait for one Agent result before calling the next — emit all Agent calls at once. Each agent:
- `team_name`: the created team name
- `name`: role name in lowercase-hyphens
- `subagent_type`: general-purpose
- `model`: sonnet
- `run_in_background`: true
- `prompt`: use this template, filling in `{role}`, `{team_name}`, `{problem}`:

```
You are the **{role}** specialist on team "{team_name}".

## Problem
{problem}

## Your Focus
Investigate from the **{role}** perspective.

## Workflow
1. Check TaskList — claim your assigned task (TaskUpdate → in_progress)
2. Read `.claude/map.md`, `.claude/design.md` if they exist
3. Search codebase within your area (Grep, Glob, Read)
4. Run commands if needed (tests, build)
5. Send findings to team lead via SendMessage
6. Mark task completed (TaskUpdate → completed)
7. Check TaskList for remaining unblocked tasks
```

## 5. Report

Tell the user:
- Team name
- Number of agents spawned
- Role list

## Error Handling

If TeamCreate fails with an agent-teams error, tell the user:
> Agent teams feature is not enabled. Enable it in Claude Code settings or set the `CLAUDE_AGENT_TEAMS` environment variable.
