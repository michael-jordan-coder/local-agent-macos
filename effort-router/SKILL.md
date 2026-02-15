---
name: effort-router
description: Automatically determine the correct reasoning depth and output verbosity before executing any code change. Classifies tasks by scope, risk, and uncertainty to select LOW, MEDIUM, or MAX effort, then enforces matching output rules. Use before any code modification to right-size planning, explanation, and validation.
---

# Purpose

Decide the right amount of thinking and output before writing code. Prevent over-engineering simple tasks and under-planning complex ones by classifying every request into an effort level and enforcing matching output rules.

# How It Works

1. Receive a code-change request.
2. Classify the task on three axes: Scope, Risk, Uncertainty.
3. Map the classification to an effort level (LOW, MEDIUM, MAX).
4. State the chosen effort level in one line.
5. Execute the task following the rules for that level.

# Decision Model

Classify the task on these three axes before doing anything else:

## Scope
- **single-file** - Change is contained in one file.
- **multi-file** - Change touches 2+ files but structure stays the same.
- **refactor** - Change alters architecture, APIs, or data flow.

## Risk
- **low** - Mistake is easy to spot and revert; no user-facing impact.
- **medium** - Could break related functionality; limited blast radius.
- **high** - Affects critical paths, data integrity, or security.

## Uncertainty
- **clear** - Requirements are explicit; no interpretation needed.
- **discovery** - Some investigation required to determine approach.
- **ambiguous** - Requirements are vague, conflicting, or incomplete.

# Effort Levels

## LOW

### When to use
- Scope: single-file
- Risk: low
- Uncertainty: clear

### Rules
- No long explanations.
- Provide minimal diff only.
- No tests unless explicitly requested.
- Keep output concise; skip preamble.

## MEDIUM

### When to use
- Scope: multi-file
- Risk: medium
- Uncertainty: discovery (some investigation needed)

### Rules
- Short plan before coding (max 6 bullets).
- Clean diff with brief rationale per file.
- Basic validation checks (linting, type-check, smoke test).
- Surface any assumptions made during discovery.

## MAX

### When to use
- Scope: refactor or new feature
- Risk: high (critical path, security, data integrity)
- Uncertainty: ambiguous requirements

### Rules
- Full plan with numbered steps.
- Identify edge cases and document them.
- Write or update tests if relevant to the change.
- Include migration notes when altering APIs or data schemas.
- Provide a risk summary listing what could go wrong and mitigations.

# Classification Rules

A task qualifies for a given effort level when **any** of that level's trigger conditions are met on **any** axis. When axes point to different levels, use the **highest** indicated level.

Examples:
- Single-file + low risk + clear = **LOW**
- Multi-file + low risk + clear = **MEDIUM** (scope elevates)
- Single-file + high risk + clear = **MAX** (risk elevates)
- Multi-file + medium risk + ambiguous = **MAX** (uncertainty elevates)

# Enforcement

1. The skill MUST classify and decide effort level **before** writing any code.
2. The skill MUST state the chosen effort level in exactly one line at the top of its response, formatted as:

   **Effort: LOW | MEDIUM | MAX**

3. All subsequent output MUST conform to the rules of the chosen level.
4. If the effort level changes during execution (e.g., discovery reveals higher risk), re-classify and state the new level before continuing.
