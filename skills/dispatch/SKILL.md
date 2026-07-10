---
name: dispatch
description: Choose and launch the right subagent or external coding agent for delegated work. Use when the user asks to spawn subagents, dispatch work, run parallel agents, compare agent surfaces, select between Cursor Agent (`agent`), Antigravity CLI (`agy`), Codex, Claude Code, or choose models/reasoning levels based on task difficulty, risk, context size, speed, and implementation complexity.
---

# Dispatch

Dispatch work only when delegation is explicitly requested or local instructions allow it. Start by identifying the immediate critical-path task to keep locally, then delegate bounded, independent sidecar tasks that can run in parallel.

## Workflow

1. Classify the task by difficulty, blast radius, coupling, and needed tools.
2. Decide whether delegation is justified. Keep tightly coupled, urgent, or blocking work local.
3. Choose the surface: built-in subagent tool, `agent`, `agy`, `codex`, or `claude`.
4. Verify live model availability before naming exact external CLI models.
5. Give each agent a narrow prompt, explicit ownership, and expected output.
6. Continue local non-overlapping work while dispatched agents run.
7. Review returned work before integrating it; do not assume agent output is correct.

## Surface Selection

- Use built-in `spawn_agent` first when available and the work fits local multi-agent delegation. Prefer it for codebase exploration, disjoint implementation slices, and verification that can run in parallel.
- Use `agent` (Cursor Agent) when Cursor-specific model variety, Cursor worktrees, or Cursor workspace context is useful. Use `agent --print --output-format json` for scriptable one-shot tasks and `agent models` or `agent --list-models` for current model IDs.
- Use `agy` (Antigravity CLI) when the task should run through Antigravity project context or its available Gemini/Claude/OpenAI model routes. Use `agy --print` for one-shot tasks and `agy models` for current model availability.
- Use `codex` when the task benefits from Codex behavior, OpenAI coding models, local sandbox controls, or Codex plugin/MCP context. Use `codex exec` for non-interactive tasks and `codex debug models` for the model catalog.
- Use `claude` when the task benefits from Claude Code features, background agents, Claude-specific review, or Anthropic model behavior. Use `claude -p` for one-shot tasks, `claude --bg` plus `claude agents` for background work, and `claude --help` for current model alias guidance.

Prefer the built-in subagent tool over shelling out when both can do the job, because it returns structured agent IDs and integrates with the current session. Use external CLIs when the user names one, the requested model only exists there, or the external agent's project/worktree/background semantics matter.

## Difficulty And Model Fit

Map model strength to task difficulty, not to preference.

- Trivial: formatting, simple grep questions, tiny edits, or command output summarization. Keep local or use the fastest model. Built-in: `gpt-5.6-luna` with low/medium effort. External: fast/low mini, flash, nano, or default auto modes.
- Routine: well-scoped bug fixes, small tests, localized refactors, basic docs, or one-module analysis. Use everyday coding models. Built-in: `gpt-5.6-terra` medium, or `gpt-5.6-luna` high when cost/speed matters.
- Complex: cross-module changes, ambiguous bugs, migrations, security-sensitive reviews, architecture tradeoffs, or tasks needing long context and tool use. Use frontier/high reasoning. Built-in: `gpt-5.6-sol` high or xhigh; use `max` for the hardest tasks and `ultra` when automatic task delegation is beneficial. `gpt-5.6-terra` high/xhigh is the balanced alternative.
- Exploratory: broad codebase reconnaissance with specific questions. Use explorer-style subagents with medium/high effort; give each a distinct question. Favor speed and parallelism over maximum model strength unless the question is subtle.
- Risky implementation: tasks that write files across different domains. Split by ownership, use worker-style agents, require changed path lists, and reserve the strongest model for integration or review.

Built-in `spawn_agent` model overrides currently exposed by the environment:

- `gpt-5.6-sol`: latest frontier agentic coding model; reasoning `low`, `medium`, `high`, `xhigh`, `max`, `ultra`; priority tier and `fast` speed tier available.
- `gpt-5.6-terra`: balanced agentic coding model for everyday work; reasoning `low`, `medium`, `high`, `xhigh`, `max`, `ultra`; priority tier available.
- `gpt-5.6-luna`: fast, affordable agentic coding model; reasoning `low`, `medium`, `high`, `xhigh`, `max`; priority tier available.

Omit built-in model overrides unless the user asks for one or the task clearly needs a different strength/speed tradeoff than the parent model.

## Live Model Discovery

External model catalogs change. Before presenting exact model IDs or dispatching through an external CLI, run the relevant discovery command when feasible:

```bash
agent models
agy models
codex debug models
claude --help
```

Use the discovered names as current availability, then group them by capability for the user:

- Fast/cheap: flash, mini, nano, spark, fast, low-effort, or non-thinking variants.
- Balanced: default, auto, medium, sonnet, composer, or standard coding models.
- Deep reasoning: high, xhigh, max, thinking, opus, pro, frontier, or long-context variants.
- Code-specialized: codex, code, composer, Cursor/Claude/Codex coding agents, and model names that explicitly mention code.
- Long-context: models labeled 1M or otherwise advertising large context.

If a discovery command fails because auth, keychain, logging, networking, or sandbox permissions block it, report that limitation and fall back to a conservative model class rather than inventing exact availability.

## Prompting Dispatched Agents

Every dispatch prompt should include:

- The concrete task and expected output.
- The files, directories, or responsibility the agent owns.
- Whether the agent may edit files or must stay read-only.
- A warning that other agents or the user may be editing the same repo and it must not revert unrelated changes.
- Any model/speed/effort choice and why.
- A concise final-report contract, such as changed paths, findings, commands run, or blockers.

For implementation agents, use disjoint write scopes. For exploration agents, ask specific questions rather than broad "understand the repo" prompts. For review agents, ask for findings first with file/line references and missing-test risks.

## Safety Rules

- Do not spawn agents merely because the task is large; spawn only when delegation is allowed and the subtask is independent.
- Do not hand off the immediate blocker if the main thread needs its result before doing anything useful.
- Do not duplicate the same investigation across multiple agents unless independent confirmation is explicitly valuable.
- Do not use dangerous permission bypass flags unless the user explicitly authorizes that risk and the workspace is externally sandboxed.
- Do not integrate generated patches without reading them and running appropriate checks.
