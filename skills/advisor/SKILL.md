---
name: advisor
description: Reference for querying frontier advisor models from the terminal — Claude Code with the Opus 5 model and Codex with gpt-5.6-sol at high reasoning. Use whenever the user wants to ask an advisor model, get a second opinion from Claude Code or Codex, run a one-shot query against opus or gpt-5.6-sol, or mentions "advisor", "ask opus", "ask sol", or consulting an external frontier model on a question.
metadata:
  tools:
    - source: mise
      command: claude
      spec: github:anthropics/claude-code@2.1.237
    - source: mise
      command: codex
      spec: npm:@openai/codex@0.148.0
---

# Advisor

Documents the exact commands for running a one-shot query against the two advisor setups. Both run non-interactively, write the answer to a file, and exit — suitable for scripting, piping, and parallel dispatch.

**Every command in this file writes to a file. There is no correct invocation that does not.** Pick the output path before you launch — see [Saving the output](#saving-the-output--do-this-every-time) for why and for the naming convention. If you catch yourself running an advisor command without a path in it, stop and add one.

## Claude Code + Opus 5

```bash
claude -p "<query>" --model claude-opus-5 < /dev/null > advisor-opus-<topic>.md 2>&1
```

Then read `advisor-opus-<topic>.md`. The file is the deliverable; the terminal shows nothing by design.

- **`< /dev/null` is required when the query is an argument.** Without it `claude -p` waits ~3s for stdin and then prepends `Warning: no stdin data received in 3s…` to its output — which `2>&1` folds straight into the answer file. Omit it only when deliberately piping the query in.
- `-p` / `--print` runs non-interactively and prints the result to stdout, which the redirect captures.
- `--model` accepts the alias `opus` or the full name `claude-opus-5`.
- Runs in the current working directory; `cd` to the relevant repo first if the query needs codebase context.
- Long or multi-line queries can be piped instead — that supplies stdin, so drop the `< /dev/null`: `cat question.md | claude -p --model claude-opus-5 > advisor-opus-<topic>.md 2>&1`.

## Codex + GPT-5.6 Sol at high reasoning

```bash
codex exec -m gpt-5.6-sol -c model_reasoning_effort=high \
  -o advisor-sol-<topic>.md "<query>" 2>advisor-sol-<topic>.trace > /dev/null
```

Then read `advisor-sol-<topic>.md`. All three streams are accounted for: the answer to the `-o` file, the trace to the `.trace` file, and the stdout copy discarded.

- **Run Codex from inside the target git repo.** Outside a trusted directory it refuses with `Not inside a trusted directory and --skip-git-repo-check was not specified`, exits without writing the `-o` file at all, and puts the reason only in the trace. A missing answer file plus a tiny trace is this, not a model failure. Use `-C <dir>` or `cd` first; the `-o` path itself can point anywhere.
- `-o` / `--output-last-message` writes the final answer to a file **in addition to** printing it on stdout — it does not redirect it. The `> /dev/null` is what keeps the duplicate off the terminal; the file is the copy that matters.
- Codex streams its runtime/progress trace to **stderr**. Send it to a `.trace` file rather than `/dev/null`: a discarded trace is the usual reason an advisor run looks like it returned nothing — it is where refusals, sandbox errors, and mid-run progress actually appear. This is CLI-only and does not affect the interactive TUI — there is no config setting, the trace is simply the stderr stream. See the [non-interactive-mode docs](https://learn.chatgpt.com/docs/non-interactive-mode).
- `codex exec` is the non-interactive mode; the prompt can also come from stdin (`cat question.md | codex exec -m gpt-5.6-sol -c model_reasoning_effort=high -o advisor-sol-<topic>.md 2>advisor-sol-<topic>.trace > /dev/null`).
- `-c model_reasoning_effort=high` sets the reasoning level. `gpt-5.6-sol` also supports `low`, `medium`, `xhigh`, `max`, and `ultra`; `high` is the advisor default here.
- The default sandbox is read-only, which is the right posture for advisory queries.

## Saving the output — do this every time

Advisor answers are long and expensive to regenerate. **Decide the output path before launching the command**, not after. A run whose answer only went to a terminal that scrolled, to a truncated tool result, or to a backgrounded job with no redirect is a lost run — it has to be paid for again.

Rules:

1. **Pick the path first.** Use a scratchpad or repo-local directory and a descriptive name: `advisor-opus-<topic>.md`, `advisor-sol-<topic>.md`. Never `out.txt`.
2. **All output goes to files — nothing to the terminal.** Redirect the answer, and redirect the trace too. Do not use `tee`: an advisor answer is far longer than a tool result will hold, so the terminal copy is truncated noise while the file is the real artifact.
3. **Never `2>/dev/null`.** Send stderr to a `.trace` file instead. Discarding it is what turns a failed run into a silently empty file with no explanation.
4. **An empty or missing answer file means _still running_, not failed.** Both tools write the answer at completion, not incrementally: Opus buffers and flushes at the end, and Codex's `-o` file does not exist until the final message. A `0` from `wc -c` or a `No such file` partway through a run is the normal mid-flight state. Wait for the process to exit before concluding anything.
5. **Never re-run to "see the output this time."** That is the expensive mistake this whole section exists to prevent — it pays for the same answer twice and usually a third time. If a finished run really did produce nothing, read the `.trace` file for the reason; do not relaunch blind.
6. **Wait for exit in the same command that launched the run.** Checking the files from a later shell invocation is what makes a mid-flight run look like a failure. See [Running both](#running-both) for the `wait` form and the detached form.
7. **One file per advisor.** Do not append two advisors' answers to the same file; comparison requires them separate.
8. **Backgrounded runs follow the same rules.** A backgrounded job's stdout is not captured at all, so the redirect is not optional there — it is the only copy.

## Running both

The two commands are independent — when querying both for comparison, launch them in parallel (e.g. background shell jobs) and capture each output to its own file rather than running them serially.

**Launch and wait in the same shell command.** Background jobs do not reliably survive the shell invocation that started them, so a separate follow-up command cannot see them finish — it sees a half-written file and reports a failure that did not happen.

```bash
claude -p "<query>" --model claude-opus-5 < /dev/null > advisor-opus-<topic>.md 2>&1 &
codex exec -m gpt-5.6-sol -c model_reasoning_effort=high \
  -o advisor-sol-<topic>.md "<query>" 2>advisor-sol-<topic>.trace > /dev/null < /dev/null &
wait
wc -c advisor-opus-<topic>.md advisor-sol-<topic>.md
```

Give this a generous timeout. A substantive review takes minutes, and an advisor killed at the two-minute mark has produced nothing but a trace file.

### When the run outlives the timeout

For reviews too long to hold a shell open, detach the run and poll the files in later commands. `nohup` plus `< /dev/null` is what lets the process survive its parent.

```bash
nohup codex exec -m gpt-5.6-sol -c model_reasoning_effort=high \
  -o advisor-sol-<topic>.md "<query>" 2>advisor-sol-<topic>.trace > /dev/null < /dev/null &
echo $!   # keep the PID
```

Poll with `kill -0 <pid>` to test whether it is still alive. While the PID lives, a missing answer file is expected — keep waiting. Once the PID is gone, the answer file is final: read it, or read the trace if it is genuinely empty.
