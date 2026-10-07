# Verification

Source: https://github.com/hexuria/impeccable-rust (MIT)

"It compiles and the tests pass" is the start of the job. Show the code is not broken under chaos and edge cases, name the **oracle** (reference implementation, property, or model) that would catch it being wrong, and give every important failure mode an **owner**. Spend heavy tools where failure hurts.

Work through each section that fits the change, and say what you ran and what you deliberately skipped (no concurrency means no Loom).

## Testing

- Assert invariants. A panic on a broken assumption beats silent wrongness. In production code, the strict Clippy lints in [clippy.md](clippy.md) still apply, so return an error or use `debug_assert!`.
- Test error paths. Litmus test: temporarily replace a `return Err(...)` with `continue` (or otherwise skip the error return). If the suite still passes, error-path coverage is broken. Tests must trigger and check the exact `Err`.
- Run Miri on tests that touch `unsafe`, custom allocators, or subtle provenance: `cargo +nightly miri test`.
- Run `cargo +nightly careful test` on the same tests as a fast second pass. It rebuilds std with debug assertions and extra UB checks and runs the FFI and syscalls Miri cannot. It misses much of what Miri finds, so it runs beside Miri.
- Use sanitizers for threading, memory access, or FFI beyond what Miri can run. They are nightly compiler flags, and they report only what a run executes:
  - `address`: out-of-bounds access, use-after-free, leaks. On macOS set `ASAN_OPTIONS=detect_leaks=1`.
  - `thread`: data races in the schedules that ran (Loom searches the interleavings).
  - `memory`: reads of uninitialized memory. Linux only.
  - Command: `RUSTFLAGS="-Zsanitizer=<kind>" RUSTDOCFLAGS="-Zsanitizer=<kind>" cargo +nightly test --target <host-triple>`. Add `-Zbuild-std` (needs `rust-src`) for `thread` and `memory`, else the link fails or reports noise. Add `-Zsanitizer-memory-track-origins` for `memory`. Use a separate `CARGO_TARGET_DIR` so normal builds stay clean.
- A test that passes only on retry has failed. Run `cargo nextest` with `flaky-result = "fail"` in `.config/nextest.toml`, reproduce with `--stress-count`, and find the interleaving with Loom or `shuttle`. Rerunning until green is not a result.
- Coverage (`cargo llvm-cov`, `cargo llvm-cov nextest`; `--branch` needs nightly) finds code no test runs. It is a gap finder, not a claim. A covered line whose `cargo mutants` mutant is missed ran but was never checked, unless the mutant is equivalent (`<` to `<=` where both branches return the same value). Record a confirmed equivalent mutant in `exclude_re` in `.cargo/mutants.toml` with a comment. `--in-diff` scopes mutants to the change.

## Chaos

Add at least one chaos layer that fits:

| Kind                                | Tools                              |
| ----------------------------------- | ---------------------------------- |
| Thread and task schedules           | `shuttle`                          |
| Network faults, partitions, crashes | `turmoil`                          |
| Values                              | `proptest`, `quickcheck`, `bolero` |
| Logic                               | `cargo-mutants`                    |

- For a reimplementation (custom map, codec, parser), property-test against a trusted oracle such as std, and assert broad invariants such as "never panics".
- For a rewrite, port, or optimization of working code, the old implementation is the oracle. Keep it in the tree, run generated inputs through both, compare results, state, and effects, and delete it only after that **differential** suite is green. A change with no oracle and no invariant has a weak correctness claim; say so in the report.
- Write each property once. A `bolero::check!` harness runs under the random engine in `cargo test` (about one second of inputs), under libFuzzer, AFL, or honggfuzz, and under Kani (`cargo bolero test --engine kani <target>`). One harness per property stops the property test, the fuzz target, and the Kani harness from drifting into three different properties. The `cargo test` sample misses narrow cases such as one magic value, so run the harness under a fuzzer or Kani before you claim the property.

## Exhaustive verification

Keep these on the smallest core that must be correct.

- **Loom** for the concurrent executions of lock-free, atomic, or custom sync code. Its memory model is partial (no load buffering, `SeqCst` treated as `AcqRel`); state that limit with the claim.
- **Kani** for symbolic inputs around `unsafe`, and for high-risk logic whose named property must hold for every input. Kani compiles concurrent code as if it were sequential, so a concurrency claim never rests on Kani. Set `#[kani::unwind(n)]` and report n; a failed unwinding assertion means the bound did not cover every iteration.

## Risk to owner

Before you recommend a tool, read the workspace: `Cargo.toml` and members, `src/`, `crates/`, `tests/`, `benches/`, `fuzz/`, CI and task files (`.github/workflows/`, `xtask`, `justfile`, `Makefile`), `AGENTS.md`, `CONTRIBUTING.md`, `docs/`, and any `formal/`, `spec/`, or `proof/` tree. Search for state machines, reducers, queues, retry, cancel, timeouts, recovery, journals, persistence, locks, atomics, channels, spawn, `unsafe`, FFI, protocols, parsers, and serialization. A tool counts as an owner only where it runs in CI or another enforced gate against that failure class.

Assign every failure class the crate actually has. This is a decision table, not a stack to install.

| Failure class                                                   | Preferred owner                                                                          |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Deterministic logic                                             | Unit, property, or differential tests                                                    |
| Rewrite, port, or optimization of working code                  | Differential tests against the retained old implementation                               |
| Untrusted input                                                 | Fuzz                                                                                     |
| Unsafe or provenance                                            | Miri, plus fuzz or Kani; `cargo careful` and sanitizers for FFI and code Miri cannot run |
| Small concurrent implementation                                 | Loom                                                                                     |
| System interleavings, deadlock, liveness, recovery architecture | TLA+ for the design; `turmoil` or `shuttle` for the Rust                                 |
| Crash persistence                                               | Crash and fault tests; add TLA+ when recovery architecture is the risk                   |
| Mathematical kernel                                             | Kani for a bounded property; Creusot or Verus for contracts; Lean for a theorem          |
| Several DSLs or frontends                                       | Differential or conformance tests                                                        |
| Public API break                                                | `cargo-semver-checks`, `cargo public-api` ([api-design.md](api-design.md))               |
| Vulnerable or unvetted dependency                               | `cargo deny`, `cargo-vet`, `cargo auditable` ([dependencies.md](dependencies.md))        |
| Compromised CI workflow                                         | `zizmor`                                                                                 |
| Performance regression                                          | Benchmark gate on low-noise metrics ([performance.md](performance.md))                   |

Deterministic logic stays on tests. It becomes a mathematical kernel only when a named property must hold for every input and tests cannot close it.

### Formal tools

- **TLA+** owns system-level designs where correctness depends on how actors interleave: workers, schedulers, queues, ownership handoff, retry, timeout, cancellation, crashes, recovery, distributed state, deadlock freedom, liveness. A retry inside one task stays on Rust tests. Document the model's state variables, actions, invariants, liveness and fairness assumptions, bounds, abstractions, and the Rust each piece maps to. TLC enumerates only the finite instance its config sets; simulation mode samples; Apalache checks to a depth. None of these is a proof; a checked TLAPS proof is.
- **Stateright** is the alternative when the actors can be written in Rust: it model-checks the same actor code it runs, so model and implementation cannot drift. Check its maintenance before it owns a failure class.
- **Creusot** proves contracts (`#[requires]`, `#[ensures]`, `#[invariant]`) on Rust through Why3; concurrency support is limited. **Verus** writes spec and proof code beside exec Rust in `verus!` and checks it with Z3.
- **Lean** only for a small kernel where the theorem is the point (replay algebra, normalization, monotonicity, a scheduler algorithm). Each artifact must answer: what does this establish that Rust tests do not? Derive the Lean from the Rust with Aeneas (safe Rust, no concurrency) or hax (crypto and protocol code) when the kernel fits.

## Anti-drift

Four green suites can still be four different semantics. Flag a Rust reducer, a TLA+ transition relation, a Lean step function, and a fixture interpreter that encode the same steps. Classify each extra model as a necessary abstraction, a formal specification, a useful differential implementation, accidental duplication, or verification theater (a green run with no owner, no bounds, and no link to production Rust).

When more than one model is necessary, pin them with **conformance**: a canonical transition corpus, model-generated traces, trace replay, or differential execution. Prefer records of `initial_state`, `event`, `expected_next_state`, `expected_effects` (or the sequence form), and make production Rust execute them.

For a workflow language or DSL, verify its meaning at the compile step into a shared Rust IR. Rust owns I/O, effects, persistence, scheduling, and recovery; a verified frontend does not become the runtime.

Follow this block on every change, and copy it into `AGENTS.md` or `CONTRIBUTING.md` when you implement a verification change:

> Any change to observable semantics names the verification boundary it affects.
>
> - Concurrency, interleaving, scheduling, retry, cancellation, recovery, ownership handoff, or liveness updates the system model, or the change states why that model is unaffected.
> - Executable Rust behavior updates the Rust verification layer. A theorem-owned kernel updates its proof. Workflow or DSL semantics update conformance or differential tests.
> - One state machine lives in one place; extra models link to it through conformance. Passing independent suites does not establish equivalence.

## Audit and implementation modes

A verification review is an **audit**: read-only on the first pass. Report the architecture, risk, and current-verifier maps; duplication, drift, gaps, and the owner of each failure; each recommendation marked REQUIRED, USEFUL, OPTIONAL, NOT JUSTIFIED, or REMOVE; and a conformance plan, CI split, and migration order. Use audit mode also for any verifier or formal model you would add, remove, or replace without being asked.

A requested code change is not an audit. Make it with the Rust checks the risk table assigns, and recommend any new formal model instead of writing it.

When the user accepts the audit, implement in this order:

1. Add missing conformance for each model the audit keeps.
2. Add the high-value Rust checks the risk table names.
3. Write down semantic ownership.
4. Strengthen a formal model only where it owns a real failure.
5. Remove accidental duplication.
6. Simplify CI.

Remove a verifier only after the guarantee that replaces it is named, in place, and passing.

## CI shape

Minimum credible set, adapted to the crate:

1. `cargo test`, Clippy, rustfmt, and `unsafe_op_in_unsafe_fn` denied on crates with `unsafe`. Runs on every crate.
2. Miri for `unsafe`, allocator, and concurrency-sensitive tests.
3. At least one of property tests, mutants, or fuzzing on parsers and codecs.
4. Loom or Kani gated to the modules that need them.
5. A benchmark regression gate on low-noise metrics.
6. `cargo deny`, optional `cargo-vet`, and `cargo auditable` on release builds.
7. `cargo-semver-checks` on published crates.
8. `zizmor` on `.github/workflows`; an audit runs `zizmor --persona=auditor` to see lower-confidence findings.

Skip any item past 1 that the risk table does not justify, and split the rest by cost:

- **Pull request:** fmt, check, Clippy, tests with flaky results failing the run, property tests covering the diff, Miri on `unsafe` tests, `cargo deny`, semver checks, `zizmor` when a workflow changed, the benchmark gate, and small Loom, Kani, model-check, and conformance runs.
- **Nightly:** long fuzz campaigns, broad Miri, large TLC state spaces, fault injection, stress tests, large Loom scenarios, deterministic simulation.
- **Release:** the full matrix where the risk table justifies it, and binaries built with `cargo auditable`.

## Report

Name each claim with the narrowest fitting term: compiler-enforced, type-enforced, unit-tested, integration-tested, property-tested, fuzz-tested, mutation-tested, Miri-checked, sanitizer-checked, model-checked, bounded model-checked, exhaustively enumerated under stated bounds, theorem-proven, differentially tested, conformance-tested, crash-tested, fault-tested, or simulation-tested. Put the bounds and assumptions next to it. "Proof" means a theorem with stated assumptions; a test suite, a fuzz run, and a bounded model check (including a Kani "bounded proof") are evidence, not proofs.

End the work with:

```text
Evidence:     each check that ran, or misuse made impossible by types, with its term and bounds
Documented:   decisions and intentional gaps written down
Deferred:     what was skipped and why
Compat/deps:  new public surface or dependency hazards
Verification: the impact declaration below and the owner of each failure mode the change can break
```

Give each check its own record, so a reader can separate what was checked from what was assumed. Record only checks that ran; a clean compile is not a check of behavior.

```text
Claim (term):
Failure class and code boundary:
Verifier and command:
Property or invariant:
Inputs, state space, and bounds:
Assumptions:
Result, artifacts, and on failure the counterexample or minimal reproducer:
Blind spots:
```

Put this declaration in the PR description of a change to observable semantics, keeping only the boxes the crate can affect:

```text
Verification impact

[ ] Pure Rust deterministic behavior
[ ] Concurrency / interleaving behavior
[ ] Distributed / system state model
[ ] Crash / recovery / replay behavior
[ ] Persistence semantics
[ ] TLA+ model
[ ] Mathematical proof kernel
[ ] Workflow / DSL semantics
[ ] Unsafe / memory behavior
[ ] Property-test / fuzz surface
[ ] No verification architecture impact

Reason:
Affected invariants:
Tests or proofs updated:
```
