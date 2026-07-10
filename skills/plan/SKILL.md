---
name: plan
description: Write a PLAN.md and TODO.md for an implementation task. Use when the user asks to plan a feature, refactor, migration, or any non-trivial change before writing code. Produces a PLAN.md with the implementation design and a TODO.md checklist for tracking progress.
---

# Plan

Generate a `PLAN.md` with the implementation design and a `TODO.md` with the verification checklist before writing any code.

## Workflow

1. Read the user's request carefully. If scope or approach is ambiguous, ask one clarifying question before proceeding.
2. Explore the codebase to understand the relevant files, existing patterns, and constraints. Do not skip this step — the plan must reflect what is actually there.
3. Write `PLAN.md` in the project root (or a subdirectory the user specifies).
4. Write `TODO.md` in the same directory as `PLAN.md`.
5. Present a brief summary of the plan to the user. Do not start implementing until the user confirms.
6. During implementation: complete all steps in a phase, check off each TODO item, then commit using the exact message drafted in the plan. Move to the next phase only after the commit succeeds.

## PLAN.md structure

```markdown
# Plan: <short title>

## Goal

One paragraph: what is being built or changed and why.

## Approach

Narrative description of the implementation strategy. Include:

- Key design decisions and their rationale
- Architectural changes (new files, modules, schemas, APIs)
- Dependencies or prerequisites
- Anything explicitly out of scope

## Implementation Phases

Group steps into named phases. Each phase should be coherent enough to land as a single commit.

### Phase 1: <phase name>

- <step>
- <step>
  **Commit:** `<type>(<scope>): <short message describing what this phase delivers>`

### Phase 2: <phase name>

- <step>
- <step>
  **Commit:** `<type>(<scope>): <short message>`

...

## Risks & Tradeoffs

- <risk or tradeoff and mitigation>

## Open Questions

- <anything that needs a decision before or during implementation>
```

## TODO.md structure

```markdown
# TODO: <short title matching PLAN.md>

## Phase 1: <phase name>

- [ ] <step>
- [ ] <step>
- [ ] Commit: `<type>(<scope>): <message>`

## Phase 2: <phase name>

- [ ] <step>
- [ ] <step>
- [ ] Commit: `<type>(<scope>): <message>`

...

## Verification

- [ ] All existing tests pass
- [ ] New tests written for <feature/change>
- [ ] Manual smoke test: <describe the happy path to exercise>
- [ ] Edge cases tested: <list specific edge cases>
- [ ] No regressions in <related area>

## Review

- [ ] Code reviewed
- [ ] PLAN.md updated if approach changed during implementation
- [ ] All phase commits are clean and describe their intent
- [ ] TODO.md items all checked off
```

## Writing guidance

- Base each step in `PLAN.md` on actual file paths and symbols found in the codebase — no invented names.
- Keep the Approach section honest about tradeoffs. Do not oversell.
- TODO.md verification items must be specific: name the files, endpoints, or behaviors to check, not generic phrases like "test everything."
- If the task is a refactor, include a "no behavior change" item in Verification.
- If the task touches a database, include migration, rollback, and data-integrity checks in Verification.
- Do not add TODO items for things outside the stated scope of the plan.

## Commit guidance

- Draft the commit message for each phase in `PLAN.md` before implementation starts. Use conventional commits: `feat`, `fix`, `refactor`, `test`, `chore`, `docs`.
- The commit message should describe what the phase _delivers_, not what files changed.
- Each phase commit should leave the codebase in a working state — no broken builds or half-wired code between phases.
- If a phase turns out to need splitting during implementation, update both `PLAN.md` and `TODO.md` before continuing, then commit each sub-phase separately.
- Mark the corresponding TODO.md commit checkbox only after `git commit` succeeds.
