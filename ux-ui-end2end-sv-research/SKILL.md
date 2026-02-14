---
name: ux-ui-end2end-sv-research
description: User-input-driven end-to-end UX/UI workflow that asks only essential adaptive questions, runs targeted web research, and produces dev-ready specs from 0 to handoff (MVP scope, flows, wireframes, UI system, validation, analytics, and acceptance criteria). Use for new product or feature definition, MVP planning, competitive and industry pattern analysis, and compliance or platform-constraint verification.
---

# Purpose

Produce complete UX/UI outputs from partial user input by:

- Asking only decision-critical questions
- Running scoped web research implied by user answers
- Converting findings into actionable design implications
- Delivering implementation-ready artifacts and acceptance criteria

Maintain staff/principal-level clarity. Avoid hype language and avoid claims that one approach is "best."

# How It Works

1. Start at Phase 0 and collect only essential missing inputs.
2. Apply adaptive questioning: ask the next question only when it changes decisions.
3. Move to mandatory Phase 1 web research after Phase 0 answers.
4. Translate research into direct design implications.
5. Execute Phases 2-8 sequentially with QA gates.
6. Maintain an append-only Decision Log with alternatives and tradeoffs.
7. Output the strict response format on every response.
8. Update artifact files continuously so they stay handoff-ready.

# Required Inputs

Accept partial input and collect missing essentials. Use these fields:

- Product or feature brief (1-3 sentences)
- Target user(s) and context
- Primary JTBD
- Platform (web/mobile/desktop)
- Constraints (time, business, legal, tech)
- Success metric (at least one number and timeframe)
- Existing design system/components (if any)
- Market or industry keywords (if relevant)

# Adaptive Questioning Protocol

## Rules

- Ask as many questions as needed, but only when each question is essential.
- Ask follow-up questions only if the answer can change:
  - UX structure
  - Constraints or risks
  - Success criteria or metrics
  - Required research targets
- Avoid generic discovery questions.
- Avoid subjective questions unless they unblock a concrete decision.
- Prefer multiple-choice or short-answer prompts.
- Avoid asking multiple questions when one answer can infer the rest.

## Core 5 Questions (ask first, always)

1. What is the product or feature in 1 sentence (promise, not implementation)?
2. Who is the primary user (role + context + device)?
3. What is the primary JTBD (When... I want to... so I can...)?
4. What is the success metric (one number) + timeframe?
5. What are the constraints: time to ship, must-have requirements, and hard limitations (legal/tech/business)?

## Follow-Up Decision Rule

Ask the next question only if missing information blocks one of:

- Scope boundary
- Flow branch logic
- State behavior (empty/loading/error)
- Validation rules or microcopy
- Compliance requirements
- Research target selection
- Success instrumentation

# Web Research Protocol

Run Phase 1 web research after receiving Phase 0 answers.

## Trigger Rules

Always research items directly implied by answers:

- Competitors or alternatives explicitly mentioned
- Industry patterns relevant to the domain (for example onboarding, payments, scheduling, booking)
- Regulatory or compliance constraints if domain suggests them (for example health, finance, identity)
- Platform conventions and accessibility standards for the target platform
- Pricing and expectation benchmarks only when pricing is explicitly relevant

## Research Method (Strict)

1. Convert user answers into a Research Plan:
   - 3-8 research questions
   - 2-5 search queries per question
   - One bullet: "What would change our design?"
2. Gather only relevant sources.
3. Extract findings in this structure:
   - Pattern
   - Why it works
   - Where it fails
   - Implementation notes
4. Convert findings into direct "Design Implications."
5. Cite every source with source name, date (if present), and link.
6. Exclude irrelevant research.

## Research Quality Bar

- Each research item must produce at least one design implication.
- Each implication must map to at least one phase deliverable.
- Flag unknowns explicitly instead of guessing.

# Gated Workflow Phases

## Phase 0 - Intake and Alignment

Deliverables:

- Product promise (1 sentence)
- Problem statement (who/what/why now)
- Persona and usage context
- JTBD
- Constraints
- Success metric draft

QA Gate:

- Pass only if a new user can understand "what it is" in 5 seconds.
- If not, rewrite the promise and problem statement.

## Phase 1 - Web Research Sprint (Mandatory)

Deliverables:

- Research Plan (questions + queries + "what changes design")
- Competitive or alternative scan (3-10)
- Key patterns (5-12)
- Known pitfalls and edge cases (5-10)
- Compliance and standards notes when relevant

QA Gate:

- Pass only if every research item yields at least one design implication.

## Phase 2 - Scope and MVP Definition

Deliverables:

- MVP in-scope list
- MVP out-of-scope list
- Non-goals
- Definition of done
- Anti-requirements

QA Gate:

- Pass only if scope can ship in 1-3 weeks.
- If not, cut scope and restate non-goals.

## Phase 3 - IA, Flows, and State Model

Deliverables:

- Screen inventory
- Happy path
- At least 3 alternate flows
- State model including empty/loading/error states
- Edge-case path notes

QA Gate:

- Pass only if no step depends on hidden knowledge.

## Phase 4 - UX Wireframes (Text-First)

Deliverables per screen:

- Information hierarchy (sections)
- Interaction rules
- Validation rules
- Microcopy (real copy, not placeholders)
- Empty/loading/error copy

QA Gate:

- Pass only if each screen has one clear primary action and an obvious next step.

## Phase 5 - UI System and Components

Deliverables:

- Token guidance (typography, spacing, radius, color usage)
- Component inventory
- Component states (default/hover/focus/disabled/loading/error/success)
- Accessibility notes (focus, contrast, keyboard, screen-reader considerations)

QA Gate:

- Pass only if no one-off component is required for core flows.

## Phase 6 - Hi-Fi UI Specs (Dev-Ready)

Deliverables:

- Final screen specs
- Responsive behavior rules
- Motion rules (minimal and purposeful)
- Content rules (length limits, truncation, overflow behavior)

QA Gate:

- Pass only if developers can implement without asking "what happens if...?"

## Phase 7 - Instrumentation and Validation Plan

Deliverables:

- Event taxonomy and event properties
- Funnel definition
- Usability test script (5 tasks)
- Success criteria mapped to hypotheses

QA Gate:

- Pass only if metrics directly map to hypotheses and success metric.

## Phase 8 - Handoff Pack

Deliverables:

- Master spec document
- Acceptance criteria per feature
- Edge-case checklist
- Risks and mitigations

QA Gate:

- Pass only if "If built exactly, what can still fail?" is explicitly answered.

# Strict Response Format (Use Every Response)

1. Current Phase: X
2. Essential Questions (only if needed; otherwise "None")
3. Assumptions (explicit, numbered)
4. Web Research (if Phase 1+):
   - Research Plan
   - Sources + Findings
   - Design Implications
5. Deliverables
6. QA Gate (pass/fail + fixes)
7. Decision Log (append-only: decision, alternatives, tradeoff)
8. Next Actions

# Artifact File Outputs

Create and maintain these files:

- `/spec.md` - single source of truth across phases
- `/research.md` - research plan, sources, findings, implications
- `/flows.md` - IA, flows, state model, edge cases
- `/wireframes.md` - text-first wireframes with microcopy and validation
- `/ui-system.md` - tokens, components, and state definitions
- `/analytics.md` - event taxonomy, funnels, hypotheses mapping
- `/handoff.md` - acceptance criteria, risks, mitigations, edge-case checklist

# Decision Log Rules

- Keep Decision Log append-only.
- Record every major product, UX, UI, validation, and analytics decision.
- For each entry include:
  - Decision
  - Alternatives considered
  - Tradeoff accepted
  - Impacted artifact files

# Global Quality Bar Checklist (Run at End of Every Run)

- Promise is clear in 5 seconds
- MVP scope is explicit (in/out)
- Flows include edge, empty, loading, and error states
- Microcopy is real and consistent
- Validation rules are defined
- Accessibility basics are covered (focus, contrast guidance, keyboard)
- Analytics events map to success metrics
- Decision Log includes tradeoffs
- Dev handoff includes acceptance criteria

# Quick Start Example

## Example Core 5 Answers

1. Product promise: "Help independent therapists fill canceled appointments quickly through a same-day booking waitlist."
2. Primary user: "Solo therapist in private practice, managing schedule on desktop during office hours; patients use mobile."
3. JTBD: "When cancellations happen, I want to notify eligible patients instantly so I can recover lost revenue without manual outreach."
4. Success metric: "Increase same-day slot fill rate by 20% within 45 days of launch."
5. Constraints: "Ship in 2 weeks; must use existing auth and calendar APIs; must meet HIPAA-adjacent privacy expectations; no SMS in v1."

## Example Research Plan

Research Question 1: How do leading scheduling and waitlist products handle same-day slot backfill?

- Queries:
  - "appointment waitlist same day booking UX pattern"
  - "healthcare scheduling cancellation fill workflow"
  - "calendar app waitlist user flow examples"
- What would change our design?
  - Notification sequence, claim window, fallback rules.

Research Question 2: What messaging and consent patterns reduce drop-off in patient notification flows?

- Queries:
  - "healthcare notification consent UX"
  - "in-app notification preference center best practices"
  - "appointment reminder opt-in conversion benchmarks"
- What would change our design?
  - Opt-in copy, preference defaults, and validation requirements.

Research Question 3: What compliance constraints shape reminders and patient data handling?

- Queries:
  - "HIPAA appointment reminder minimum necessary"
  - "FTC health app privacy guidance"
  - "US healthcare app notification privacy requirements"
- What would change our design?
  - Allowed message content, logging requirements, and redaction behavior.

Research Question 4: What are platform expectations for accessible time-slot selection on web and mobile?

- Queries:
  - "WCAG accessible date picker patterns"
  - "mobile booking flow accessibility errors"
  - "keyboard accessible scheduling interface"
- What would change our design?
  - Component choice, focus order, and error handling patterns.

## Example Phase 1 Summary + Design Implications

Sources + Findings:

- Google Material Design, date unknown, [https://m3.material.io/components/date-pickers/overview](https://m3.material.io/components/date-pickers/overview)
  - Pattern: explicit date/time confirmation reduces accidental selections.
  - Failure mode: dense calendars increase error rate on small screens.
- Nielsen Norman Group, date present on article page, [https://www.nngroup.com/](https://www.nngroup.com/)
  - Pattern: progressive disclosure improves form completion in multi-step scheduling.
  - Failure mode: hidden constraints shown too late cause abandonment.
- W3C WAI WCAG overview, date present on page, [https://www.w3.org/WAI/standards-guidelines/wcag/](https://www.w3.org/WAI/standards-guidelines/wcag/)
  - Pattern: predictable focus order and explicit error identification are required for accessibility.
  - Failure mode: custom date controls without keyboard support block completion.

Design Implications:

1. Use a two-step claim flow: select slot -> confirm claim, with a visible timer for hold expiration.
2. Require notification preferences before waitlist enrollment; default to least-intrusive channel.
3. Restrict reminder content to minimum necessary information and avoid sensitive details in notifications.
4. Use accessible, keyboard-operable slot selection with inline error copy and focus return on failure.
5. Add explicit empty/loading/error states for waitlist status, slot contention, and failed claim retries.
