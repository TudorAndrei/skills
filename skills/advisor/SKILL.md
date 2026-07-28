---
name: advisor
description: Reference for querying frontier advisor models from the terminal — Claude Code with the Opus 5 model and Codex with gpt-5.6-sol at high reasoning. Use whenever the user wants to ask an advisor model, get a second opinion from Claude Code or Codex, run a one-shot query against opus or gpt-5.6-sol, or mentions "advisor", "ask opus", "ask sol", or consulting an external frontier model on a question.
---

# Advisor

Documents the exact commands for running a one-shot query against the two advisor setups. Both run non-interactively, print the answer to stdout, and exit — suitable for scripting, piping, and parallel dispatch.

## Claude Code + Opus 5

```bash
claude -p "<query>" --model claude-opus-5
```

- `-p` / `--print` runs non-interactively and prints the result.
- `--model` accepts the alias `opus` or the full name `claude-opus-5`.
- Runs in the current working directory; `cd` to the relevant repo first if the query needs codebase context.
- Long or multi-line queries can be piped: `cat question.md | claude -p --model claude-opus-5`.

## Codex + GPT-5.6 Sol at high reasoning

```bash
codex exec -m gpt-5.6-sol -c model_reasoning_effort=high "<query>" 2>/dev/null
```

- `codex exec` is the non-interactive mode; the prompt can also come from stdin (`cat question.md | codex exec -m gpt-5.6-sol -c model_reasoning_effort=high 2>/dev/null`).
- Codex streams its runtime/progress trace to **stderr** and writes only the final answer to **stdout**. Append `2>/dev/null` to suppress the trace, or `2>codex.trace` to keep it in a file for debugging without cluttering the terminal. This is CLI-only and does not affect the interactive TUI — there is no config setting, the trace is simply the stderr stream. See the [non-interactive-mode docs](https://learn.chatgpt.com/docs/non-interactive-mode).
- `-c model_reasoning_effort=high` sets the reasoning level. `gpt-5.6-sol` also supports `low`, `medium`, `xhigh`, `max`, and `ultra`; `high` is the advisor default here.
- Use `-C <dir>` to point Codex at a specific repo, and `-o <file>` / `--output-last-message` if only the final answer is needed.
- The default sandbox is read-only, which is the right posture for advisory queries.

## Running both

The two commands are independent — when querying both for comparison, launch them in parallel (e.g. background shell jobs) and capture each output to its own file rather than running them serially.
