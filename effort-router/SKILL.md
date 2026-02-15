---
name: effort-router
description: Token-smart effort router for Claude Code. Chooses the minimum effective effort level for each code-change task, enforces token-saving behaviors (compact output, diffs over full files, minimal exploration), and runs before any code edits. Classifies on scope, risk, uncertainty, and token sensitivity to select LOW, MEDIUM, or MAX effort.
---

# Mission

Choose the minimum effective effort level for each task and enforce token-saving behaviors:
- Keep context small
- Keep output compact
- Prefer diffs over full files
- Avoid unnecessary exploration

This skill MUST run before any code edits.

# Inputs

Extract from the user message:
- **Goal** (1 sentence)
- **Constraints** (explicit)
- **Files/paths mentioned** (if any)
- **"Must not change" items** (if any)
- **Rigor**: demo | production (if implied)

If missing critical info, ask at most 2 short questions. Otherwise proceed.

# Step 1 — Task Classification

## A) Scope
- **S1**: Single-file, localized change
- **S2**: Multi-file, limited surface area (2-5 files)
- **S3**: Refactor/feature, cross-cutting

## B) Risk
- **R1** (low): copy, styling, layout, UI-only, non-critical flows
- **R2** (medium): app logic, data transforms, state management, routing, caching
- **R3** (high): auth, payments, data integrity, security, build tooling, deps, migrations

## C) Uncertainty
- **U1**: clear instructions + exact location
- **U2**: some discovery needed (unknown file/entry point)
- **U3**: ambiguous requirements / needs product decisions

## D) Token Sensitivity (always assume user wants savings)
- **T1**: user provided exact file/snippet
- **T2**: user described behavior but not location
- **T3**: user asked broad/architectural changes

# Step 2 — Effort Decision (minimum effective)

## LOW (default)

Use when:
- (S1) AND (R1 or R2) AND (U1 or U2)

Token rules:
- No long explanations
- Output in unified diff only
- Do not print full files
- No alternatives; pick 1 approach
- No tests unless explicitly requested or change is risky
- Max 8 bullets total across the entire response

## MEDIUM

Use when:
- (S2) OR (R2) OR (U2), and change touches logic

Token rules:
- 1 short plan (max 5 bullets)
- Search/codebase exploration only if needed; stop early
- Output diffs only
- Add minimal verification steps (1-3)
- No extended rationale

## MAX (rare)

Use when:
- (R3) OR (S3) OR (U3)

Token rules:
- Still keep output compact
- Plan (max 8 bullets), then diffs
- Add tests only if they prevent regressions
- Explicitly list risks + rollback/migration notes (brief)

# Step 3 — Context Minimization Policy (hard rules)

Before editing:

1. Identify **Minimum Relevant Set (MRS)**:
   - Only open files that are on the execution path for the change
   - Prefer grep/search by symbol names over reading whole directories
2. Never paste entire files into the chat output unless user asks
3. Prefer patch/diff format
4. Avoid re-stating code that didn't change

Stop exploring once enough info exists to implement.

# Step 4 — Execution Rules

- Preserve existing conventions (linting, formatting, naming, patterns)
- Make the smallest correct change
- Do not refactor unrelated code
- If multiple files must change, do them in the fewest edits possible
- After edits: give a verification checklist (max 3 steps in LOW/MEDIUM)

# Output Template (must follow)

```
1) Effort: LOW | MEDIUM | MAX
2) Assumptions (only if needed, max 2 bullets)
3) Patch (unified diff)
4) Verify (max 3 bullets)
```

# Examples

- "Change button label" → **LOW**
- "Fix state bug across 3 components" → **MEDIUM**
- "Touch auth or persistence layer" → **MAX**

# Final Constraint

This skill prioritizes token efficiency over verbosity.
If unsure between two levels, choose the **LOWER** level first and escalate only if blocked.
