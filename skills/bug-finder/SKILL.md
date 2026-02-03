---
name: bug-finder
description: Run code and identify bug locations. Use this skill when a user wants to find bugs, locate errors, debug failures, or identify where problems occur in their code. This skill focuses STRICTLY on identification - it reports bug locations but does NOT suggest fixes or corrections.
---

# Bug Finder

Identify and report bug locations by running commands and analyzing output. Focus strictly on identification, not correction.

## Workflow

### 1. Get Run Command

Ask user what command to run: `pytest`, `npm test`, `go test ./...`, `cargo test`, `python main.py`, `make check`

### 2. Execute and Capture

Run command using Bash. Capture stdout and stderr.

### 3. Analyze Output

Parse for:
- Stack traces and tracebacks
- Error messages with file/line references
- Failed assertions
- Runtime exceptions
- Compiler/interpreter errors
- Test failures

### 4. Report Bug Locations

Present as numbered list with: File path:line, Error type, Message, Stack trace (if available)

Example format:

1. `src/auth/login.py:47` - TypeError: 'NoneType' object has no attribute 'strip'
   - Stack: login.py:47 → login.py:23 → main.py:156

2. `src/utils/parser.py:112` - IndexError: list index out of range
   - Stack: parser.py:112 → parser.py:89

## Rules

- **NEVER** suggest fixes - only identify and report locations
- **NEVER** modify code - this is read-only analysis
- If command succeeds with no errors, report "No bugs detected"
- If output is ambiguous, list all potential bug locations
- Include full stack traces when available
- Preserve exact file paths and line numbers from output
