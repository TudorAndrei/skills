# Performance

Source: https://github.com/hexuria/impeccable-rust (MIT)

Use this to benchmark Rust, to make working Rust faster or leaner, to hit a speedup target, or to beat another crate. For binary size, use the Binary size section of SKILL.md instead.

## Benchmarks

Cover the full profile: pathological cases, micro and end-to-end, under, at, and over capacity, and every relevant target.

Trustworthy measurement (CI fails on regression):

- Prefer instruction counts over wall time alone: `gungraun` (formerly `iai-callgrind`). It needs Valgrind, so it runs on Linux, not macOS.
- Interleave old and new to cut noise: `tango-bench`.
- Use Criterion, or the crate's existing harness, for statistical wall-clock time where users feel wall time.
- Turn the gate on explicitly. gungraun checks regressions only when limits are set (`--callgrind-limits='ir=5%'` exits 3 on a regression). tango's `compare` fails only with `--fail-fast`.
- Use a dedicated host under 100% load.

Measure what matters, not only speed: throughput and goodput (a flood of 500 responses is high throughput and zero useful work), average and peak memory, latency distributions, and outcomes against ground truth on realistic inputs. Prefer the real deployment target over a large CI machine. Record the load model (open, closed, partly open), the statistic (mean, median, histogram, CDF), and the regression rule.

## Benchmark contract

A speed claim compares equal work under equal conditions. The benchmark definitions, workloads, and build settings at the **baseline** commit form the contract, and both sides of every comparison run under it:

- Same work: same inputs, iterations, accuracy, and output, timed through the production code path.
- Same build: an optimized profile (`--release` or `cargo bench`), with the same toolchain, features, and profile settings. A dependency added or bumped is part of the candidate; declare it and run [dependencies.md](dependencies.md). A `RUSTFLAGS` or `target-cpu` value counts only when it ships to users, and then both sides get it.
- Clean iterations: state from one iteration reaches the next only when production reuses it the same way.
- One benchmark at a time on the machine.
- Repeated runs with their spread reported. One wall-clock run is an anecdote.
- A surprisingly large win is a suspected bug until the oracle and a fresh run confirm it.

Before each comparison, check against the baseline commit that these are unchanged: files under `benches/`; `rust-toolchain*`, `.cargo/config.toml`, and the `[profile.*]` tables; and `RUSTFLAGS`, `CARGO_ENCODED_RUSTFLAGS`, `CARGO_PROFILE_*`, or `rustflags` in `~/.cargo/config.toml`. A difference fails the comparison unless you waive it on the record with a reason. Note new `unsafe` lines (for Miri) and changed `Cargo.lock` packages (for the dependency checks).

To change the contract (a missing workload, a broken benchmark), say so, make the change in its own commit, and measure the baseline again on it.

## Data layout

Apply these only when a profile shows the hot path is memory- or cache-bound.

- Prefer a `u32` index into a contiguous arena over a `Box` or `Rc` pointer graph, and a generational handle (`slotmap`) once slots are reused. Keep `&T` borrows for a small graph or an API that must hand out references.
- Use struct-of-arrays for a hot loop that touches a subset of fields. Keep array-of-structs when each access needs the whole record, or when the collection is tiny.
- Store a sparse `Option` or `bool` out of band (side map, bitset, parallel array keyed by id) so a rare field does not widen every hot row.
- Box a large rare enum variant, and assert `size_of` in a test so a fatter variant fails CI. Skip the box when variants are similar in size or the indirection loses in a profile.
- Set `repr` only when layout is part of the contract: `repr(C)` for FFI or stable bytes, `repr(align(128))` or `crossbeam_utils::CachePadded` so a hot atomic does not share a cache line (64 can be too small on x86_64 and aarch64). Use `packed` only after a measurement shows padding costs more than unaligned access.

## Optimization loop

Speed work is a search: measure, change one thing, prove it is still right, race it against the baseline, keep or revert, and repeat until the gains **converge**. The contract and the oracle are firm: a change that breaks either is a failed experiment, not a result. The defaults below apply unless the user sets others.

### 1. Set up

Finish setup before you change production code.

1. Name the primary metric (latency, throughput, goodput, instructions, allocations, peak memory, startup time) and the secondary metrics that must hold.
2. Name the oracle: the old implementation kept in the tree, a reference implementation, or properties ([verification.md](verification.md)). When speed can trade against output quality (accuracy, compression ratio), quality is a metric with its own tolerance.
3. Write the workload matrix from real use: small, typical, large, pathological, cold, and warm.
4. Commit the benchmarks and the matrix. That commit is the baseline.
5. Measure the baseline in its own worktree with the same command you will use on candidates. Repeat until median and spread are stable. Record toolchain, profile, CPU, features, and inputs.

| Default    | Value                                      |
| ---------- | ------------------------------------------ |
| Target     | at least 1.2x on the primary metric        |
| Regression | at most 3% on any workload                 |
| Memory     | at most 5% peak growth                     |
| Quality    | within the baseline's run-to-run variation |

The target is a floor, not a stopping point. When the contract and the oracle cannot both hold at the target, report the best result that keeps them.

### 2. Loop

Profile before you guess: `samply record` (Linux, macOS) or `perf record` (Linux) for CPU, `dhat` for allocations, gungraun's Callgrind output for instructions and cache.

Write each hypothesis down before you try it: the code boundary, why it should move the metric, the expected size, the correctness risk, and the measurement that would refute it. Rank by expected value. Search across: work that can be removed, algorithmic complexity, repeated computation, allocation and copying, data layout, branches and vectorization, parallelism and contention, I/O and FFI boundaries, and dependency overhead.

For each hypothesis:

1. Confirm in the profile that the path is hot.
2. Make one change.
3. Run the oracle. A mismatch reverts the change.
4. Race the change against the baseline under the contract.
5. Keep the change when its gain clears the measured noise, every workload stays in tolerance, and the gain pays for its code. Commit it alone with its numbers. Otherwise revert it.
6. Append the result to the run log (`perf-log.md` unless the user names a place): hypothesis, numbers, kept or reverted. Reverted ideas stay in the log.

A kept change that adds `unsafe`, a dependency, threads, or atomics also passes its owner from the risk table in [verification.md](verification.md) before it counts.

Helper agents can propose hypotheses from reading code. Only the main loop edits the tree and runs benchmarks.

### 3. Converge

Two rounds in a row under 3% cumulative gain mean the incremental loop has converged. Then run one **breakthrough** pass that changes the shape of the computation: a better or bespoke algorithm for the real workload, removing work, fusing passes, incremental computation, batching, a data-oriented layout, a strategy chosen by input size, vectorization, parallel decomposition, or dropping generality the contract does not need. A breakthrough is farther from the baseline, so its oracle runs under a fuzzer or Kani, not only the short random sample.

Stop when the breakthrough pass also converges and no untried hypothesis of a different kind remains. An optional cleanup pass can then shrink the code, with every workload held in tolerance.

### 4. Report

Re-run the whole matrix on the final commit against the baseline, then the full oracle and the checks each touched failure class owns. Report:

- Per workload: metric, baseline, final result, speedup, and spread.
- Memory and quality against the baseline.
- Each kept change and why it is faster.
- The reverted experiments from the run log.
- Any contract waiver and its reason.
- The evidence records from [verification.md](verification.md), with blind spots.

Claim the speedup only for the workloads and bounds you measured.
