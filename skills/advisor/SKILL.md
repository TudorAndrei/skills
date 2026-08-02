---
name: advisor
description: Reference for querying frontier advisor models from the terminal — Claude Code with the Opus 5 model and Codex with gpt-5.6-sol at high reasoning. Use whenever the user wants to ask an advisor model, get a second opinion from Claude Code or Codex, run a one-shot query against opus or gpt-5.6-sol, or mentions "advisor", "ask opus", "ask sol", or consulting an external frontier model on a question.
---

# Advisor

Documents the exact commands for running a one-shot query against the two advisor setups. Both run non-interactively, write the answer to a file, and exit — suitable for scripting, piping, and parallel dispatch.

**Every command in this file writes to a file. There is no correct invocation that does not.** Pick the output path before you launch — see [Saving the output](#saving-the-output--do-this-every-time) for why and for the naming convention. If you catch yourself running an advisor command without a path in it, stop and add one.

## Claude Code + Opus 5

```bash
claude -p "<query>" --model claude-opus-5 > advisor-opus-<topic>.md 2>&1
```

Then read `advisor-opus-<topic>.md`. The file is the deliverable; the terminal shows nothing by design.

- `-p` / `--print` runs non-interactively and prints the result to stdout, which the redirect captures.
- `--model` accepts the alias `opus` or the full name `claude-opus-5`.
- Runs in the current working directory; `cd` to the relevant repo first if the query needs codebase context.
- Long or multi-line queries can be piped: `cat question.md | claude -p --model claude-opus-5 > advisor-opus-<topic>.md 2>&1`.

## Codex + GPT-5.6 Sol at high reasoning

```bash
codex exec -m gpt-5.6-sol -c model_reasoning_effort=high \
  -o advisor-sol-<topic>.md "<query>" 2>advisor-sol-<topic>.trace
```

Then read `advisor-sol-<topic>.md`. Nothing reaches the terminal: the answer goes to the `-o` file, the trace to the `.trace` file.

- `-o` / `--output-last-message` writes the final answer straight to a file. This is the reason Codex never needs its stdout captured — always pass it.
- Codex streams its runtime/progress trace to **stderr** and writes only the final answer to **stdout**. Send stderr to a `.trace` file rather than `/dev/null`: a discarded trace is the usual reason an advisor run looks like it returned nothing. This is CLI-only and does not affect the interactive TUI — there is no config setting, the trace is simply the stderr stream. See the [non-interactive-mode docs](https://learn.chatgpt.com/docs/non-interactive-mode).
- `codex exec` is the non-interactive mode; the prompt can also come from stdin (`cat question.md | codex exec -m gpt-5.6-sol -c model_reasoning_effort=high -o advisor-sol-<topic>.md 2>advisor-sol-<topic>.trace`).
- `-c model_reasoning_effort=high` sets the reasoning level. `gpt-5.6-sol` also supports `low`, `medium`, `xhigh`, `max`, and `ultra`; `high` is the advisor default here.
- Use `-C <dir>` to point Codex at a specific repo.
- The default sandbox is read-only, which is the right posture for advisory queries.

## Saving the output — do this every time

Advisor answers are long and expensive to regenerate. **Decide the output path before launching the command**, not after. A run whose answer only went to a terminal that scrolled, to a truncated tool result, or to a backgrounded job with no redirect is a lost run — it has to be paid for again.

Rules:

1. **Pick the path first.** Use a scratchpad or repo-local directory and a descriptive name: `advisor-opus-<topic>.md`, `advisor-sol-<topic>.md`. Never `out.txt`.
2. **All output goes to files — nothing to the terminal.** Redirect the answer, and redirect the trace too. Do not use `tee`: an advisor answer is far longer than a tool result will hold, so the terminal copy is truncated noise while the file is the real artifact.
3. **Never `2>/dev/null`.** Send stderr to a `.trace` file instead. Discarding it is what turns a failed run into a silently empty file with no explanation.
4. **Read the file, don't re-run.** After the command exits, `wc -c` both files, then read the answer file. An empty answer file means the run failed — the `.trace` file says why. Re-running to "see the output this time" pays for the same answer twice.
5. **One file per advisor.** Do not append two advisors' answers to the same file; comparison requires them separate.
6. **Backgrounded runs follow the same rules.** A backgrounded job's stdout is not captured at all, so the redirect is not optional there — it is the only copy.

## Running both

The two commands are independent — when querying both for comparison, launch them in parallel (e.g. background shell jobs) and capture each output to its own file rather than running them serially.

```bash
claude -p "<query>" --model claude-opus-5 > advisor-opus-<topic>.md 2>&1 &
codex exec -m gpt-5.6-sol -c model_reasoning_effort=high \
  -o advisor-sol-<topic>.md "<query>" 2>advisor-sol-<topic>.trace &
wait
wc -c advisor-opus-<topic>.md advisor-sol-<topic>.md   # both must be non-empty
```
