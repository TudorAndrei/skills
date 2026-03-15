---
name: agent-cli-design
description: Design, review, or retrofit command-line interfaces for both human users and AI agents. Use when building a new CLI, making an existing CLI agent-safe, adding machine-readable output, schema introspection, dry-run behavior, field selection, input validation, MCP support, or workflow guidance for agent-operated tools.
---

# Agent CLI Design

Design for two consumers at once: humans need discoverability and forgiveness; agents need predictability, structure, and defensive defaults.

## Workflow

1. Determine whether the task is greenfield design, retrofit, or review.
2. Inspect the current CLI surface, output modes, validation behavior, and documentation path.
3. Prioritize the agent path without removing human convenience features.
4. Specify concrete changes in this order: machine-readable output, raw structured input, runtime introspection, context-window controls, input hardening, safe mutation flow, multi-surface access.
5. Encode non-obvious invariants in the CLI itself and in skill/context files.

## Core Principles

### Preserve two paths

- Keep convenience flags, prompts, and human-friendly help when they already exist.
- Add a first-class raw payload path such as `--json` or `--params` that maps directly to the underlying schema.
- Avoid building agent support through lossy flag translations alone when nested or evolving request bodies exist.

### Prefer machine-readable I/O

- Provide stable JSON output for every command that an agent may consume.
- Prefer deterministic field names and avoid mixing prose with structured output.
- If streaming or pagination matters, prefer NDJSON or another incremental format over one large buffered array.
- If the CLI already has a text UX, add an explicit `--output json` path instead of changing the human default unexpectedly.

### Make the CLI self-describing

- Expose a runtime schema or description command so an agent can inspect inputs and outputs without external docs.
- Include required parameters, request body shape, response shape, and permission or auth requirements when relevant.
- Treat runtime introspection as the canonical source of truth for current behavior.

### Protect the context window

- Add field selection, masks, or projection flags so agents can request only the fields they need.
- Prefer paginated or streamable results for large collections.
- State explicitly in docs or skill guidance that agents should minimize response size.

### Harden inputs for hallucinations

- Assume agent inputs can be adversarial, malformed, or confidently wrong.
- Validate path-like inputs after canonicalization and sandbox writes to an intended root.
- Reject control characters in text inputs unless there is a clear need to allow them.
- Reject resource identifiers that contain embedded query fragments, anchors, or pre-encoded bytes when those are invalid for the domain.
- Encode URL path segments at the HTTP layer instead of trusting already-encoded input.

### Add safety rails for mutations

- Provide `--dry-run` for create, update, delete, or any action with side effects.
- Make dry-run validate locally and show the exact request shape the real command would issue.
- If the CLI returns untrusted external content to an agent, consider a sanitization step before handing the content back.

### Support multiple agent surfaces

- Treat the CLI binary as the core interface and layer additional surfaces on top of it.
- If the CLI wraps a structured API, expose the same operations through MCP or another typed tool interface when practical.
- Prefer environment-variable or file-based auth flows for unattended usage; avoid browser-only auth for agent paths.

## Retrofit Order

When improving an existing CLI, implement changes in this order:

1. Add machine-readable output.
2. Validate inputs defensively.
3. Add runtime schema or command description.
4. Add field selection or response-shaping controls.
5. Add `--dry-run` for side-effecting commands.
6. Ship agent-facing context or skill files that encode invariants.
7. Add MCP or another typed agent surface if the CLI maps to structured operations.

## Review Checklist

Use this checklist when asked to design or assess a CLI:

- Can an agent invoke the command without shell-escaping gymnastics or lossy flag expansion?
- Can an agent request and receive strict JSON or NDJSON?
- Can an agent discover the accepted schema at runtime?
- Can an agent limit response size before execution?
- Does the CLI reject hallucinated path traversal, encoded garbage, control characters, and invalid identifiers?
- Is there a dry-run path for every mutating command?
- Are auth flows workable in a headless environment?
- Are agent-specific rules documented in `SKILL.md`, `AGENTS.md`, or equivalent context files?

## Output Expectations

When producing recommendations or code changes for a CLI:

- Separate human-facing ergonomics from agent-facing guarantees.
- Explain tradeoffs in terms of predictability, safety, and schema fidelity.
- Prefer concrete command examples and request/response shapes over abstract advice.
- If the work is a review, identify the highest-risk agent failure modes first.

## References

- Read `references/cli-principles.md` for detailed patterns, failure modes, examples, and a fuller retrofit playbook distilled from `cli-blogpost.txt`.
