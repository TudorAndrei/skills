# CLI Principles For Humans And Agents

This reference distills the main ideas from `cli-blogpost.txt` into reusable guidance for skill users.

## Contents

- Raw payloads and schema fidelity
- Runtime introspection
- Context-window discipline
- Input hardening
- Safety rails
- Multi-surface delivery
- Practical retrofit plan
- Review prompts

## Raw Payloads And Schema Fidelity

Human-first CLIs often flatten rich request bodies into many convenience flags. That helps discoverability for a person but creates translation loss for an agent, especially when nested structures or evolving API shapes are involved.

Prefer a first-class raw payload path:

- `--json` for full request bodies
- `--params` for structured parameter objects
- stable JSON examples that mirror the underlying API or internal schema directly

Keep convenience flags if they are valuable, but do not make them the only way to express a complex request.

Signs a CLI is too human-only:

- a large flat flag surface for a naturally nested request
- custom argument naming that diverges from the underlying API schema
- no way to submit a complete object without lossy translation

## Runtime Introspection

Agents should not need long static docs embedded in prompts.

Add a command like one of these:

- `tool schema <command>`
- `tool describe <command> --output json`
- `tool help <command> --json`

Expose, at minimum:

- required and optional parameters
- request body schema
- response schema
- auth or permission requirements
- enums, field masks, and pagination behavior when relevant

For API-backed tools, dynamic introspection is more durable than copied documentation because it can reflect the current schema directly.

## Context-Window Discipline

Agents pay for every irrelevant field they ingest.

Recommended capabilities:

- field masks such as `--fields` or request-level field selectors
- pagination with page-by-page output
- NDJSON or similar incremental streaming for large result sets
- explicit guidance telling agents to request the minimum viable response

Recommended rule of thumb:

- list and get operations should support response minimization before the request is sent
- bulk output should be processable incrementally

## Input Hardening

Agent mistakes differ from human typos. Design validation around hallucination patterns, not just accidental misspellings.

Common failure modes to defend against:

- path traversal like `../../.ssh`
- resource IDs polluted with `?query=params` or `#anchors`
- pre-encoded strings such as `%2e%2e` that would be double-encoded later
- invisible control characters in generated text
- path segments with unsafe characters that need encoding at transport time

Recommended protections:

- canonicalize paths and enforce an output sandbox
- reject invalid bytes and control characters by default
- validate identifier format explicitly instead of accepting arbitrary strings
- reject embedded query fragments in fields that should be plain identifiers
- perform URL encoding in one trusted layer only

Useful framing: the CLI is the last line of defense between a hallucinated plan and a real side effect.

## Safety Rails

For mutating commands, add `--dry-run` and make it meaningful.

Good dry-run behavior:

- validates inputs and request shape locally
- shows what would be sent
- fails early on missing required fields or invalid identifiers
- does not contact the remote system unless there is no other way to validate

If the CLI returns untrusted content that an agent may reason over, consider a sanitization layer or an explicit warning that data may contain prompt injection attempts.

## Multi-Surface Delivery

A strong agent-ready CLI usually serves several surfaces from one source of truth:

- interactive shell usage for humans
- plain CLI commands for scripted automation
- MCP or JSON-RPC tooling for typed agent invocations
- environment variables or credential-file paths for headless auth

The more structured the underlying system is, the more value typed tool invocation provides. It removes shell quoting, parsing ambiguity, and brittle output scraping.

## Practical Retrofit Plan

If asked how to retrofit an existing CLI, use this order:

1. Add `--output json` or equivalent machine-readable output.
2. Audit and harden all user-controlled inputs.
3. Add `schema`, `describe`, or JSON help output.
4. Add field selection and response minimization.
5. Add `--dry-run` for every command with side effects.
6. Add agent-specific guidance files such as `SKILL.md`, `AGENTS.md`, or `CONTEXT.md`.
7. Add MCP or another typed interface for structured commands.

This order front-loads the most broadly useful and least controversial improvements.

## Review Prompts

Use prompts like these during design or review:

- What is the lossless request path for an agent?
- What is the smallest valid response an agent can request?
- How does the CLI document its current schema without external docs?
- What hallucinated inputs would reach the network or filesystem today?
- Which commands can mutate state without a dry-run?
- Which auth flows break in headless execution?
- Which parts of the CLI require a typed tool interface instead of shell invocation?

## Example Positioning

Use these distinctions when explaining design choices:

- Human DX favors discoverability, forgiving defaults, and interactive guidance.
- Agent DX favors predictability, explicit schemas, machine-readable output, and defense-in-depth.
- These goals are orthogonal, not mutually exclusive.

The practical goal is not to remove the human UX. It is to add a reliable, inspectable, low-ambiguity path that agents can use safely.
