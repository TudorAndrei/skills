# Cucumber (BDD) Tests

Sources: [cucumber-rs book](https://cucumber-rs.github.io/cucumber/main/), [cucumber-rs CHANGELOG](https://github.com/cucumber-rs/cucumber/blob/main/CHANGELOG.md), [cucumber-rs#370](https://github.com/cucumber-rs/cucumber/issues/370), [cucumber.io: better Gherkin](https://cucumber.io/docs/bdd/better-gherkin/), [cucumber.io: anti-patterns](https://cucumber.io/docs/guides/anti-patterns/), [Cargo targets](https://doc.rust-lang.org/cargo/reference/cargo-targets.html#the-harness-field), [Clippy configuration](https://doc.rust-lang.org/clippy/lint_configuration.html), and the test code of cuenv, Eclipse up-rust, and OpenFeature rust-sdk-contrib.

Use the `cucumber` crate (0.23, MSRV 1.88 as of 2026-04) to write Gherkin `.feature` files that describe behavior and run them as Rust tests. Use it for behavior that a reader outside the code must agree on. Keep unit, property, and fuzz tests as plain `#[test]` functions; Cucumber does not replace them.

## How real projects set it up

| Project                                                                                            | Layout                                                                                                                                                   | World                                             | Runner and CI                                                                                                                        |
| -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| [cuenv](https://github.com/cuenv/cuenv/tree/main/crates/cuenv/tests)                               | One `bdd` target with `harness = false` in the CLI crate. Features in `tests/bdd/features/`, one step file per domain (`env_steps.rs`, `task_steps.rs`). | One `TestWorld` with `#[world(init = Self::new)]` | Tokio `main`. Steps return `anyhow::Result` through a `StepResult` alias. A `--list` guard stops nextest from failing on the target. |
| [Eclipse up-rust](https://github.com/eclipse-uprotocol/up-rust)                                    | One target per area (`tck_uuid`, `tck_uuri`). Features come from a shared spec repository.                                                               | One small World per target                        | `cargo test --no-fail-fast --test 'tck_*' -- --junit-out-folder=…`, then upload the JUnit XML.                                       |
| [OpenFeature flagd](https://github.com/open-feature/rust-sdk-contrib/tree/main/crates/flagd/tests) | Many `gherkin_*_test.rs` files. Features come from a shared testbed submodule.                                                                           | One World per file, `init = Self::new`            | Runs Cucumber inside a `#[tokio::test]` and keeps the libtest harness.                                                               |

All three keep `cucumber` as a dev-dependency only and keep their `#[test]` unit tests next to the Cucumber tests.

## Layout

- Put feature files in a directory per domain (`features/sync/`, `features/library/`). The directory tree is the readable list of what the product does.
- Give each domain its own `[[test]]` target with `harness = false` and its own small World. One World for the whole product collects fields that most scenarios never use.
- Put the targets in a separate test crate (for example `crates/<project>-features`) when several library crates take part, or when the rest of the workspace runs under nextest (see [Runner](#runner)).
- Put steps in one `.rs` file per domain concept (`account_steps.rs`), not one file per feature file. Steps coupled to one feature cannot be reused, and the step set grows with copies.

```toml
[dev-dependencies]
cucumber = "0.23"
futures = "0.3" # or tokio, only if a step needs it

[[test]]
name = "sync" # matches tests/sync.rs
harness = false # Cucumber prints its own output instead of libtest
```

## World

- Cucumber builds a new World for each scenario, with `Default::default()` or `#[world(init = Self::new)]`. The constructor can be sync or async, fallible or infallible. Do not share state between scenarios through statics.
- Derive `Debug` on the World. `-vv` prints the World when a step fails, which is the fastest failure report you get.
- Keep fakes and test doubles in the World, built from the same trait types the unit tests use. Do not start real services in the World when a fake answers the question.

## Steps

- Return `Result` from steps. A step fails when it panics or when it returns `Err`; with `Result`, the step uses `?` and the strict Clippy lints still pass. A `harness = false` target compiles with `cfg(test)`, but Clippy exempts only `#[test]` functions and `#[cfg(test)]` items from `unwrap_used` and its siblings, so `allow-unwrap-in-tests = true` in `clippy.toml` (see [clippy.md](clippy.md)) does not cover a step function. Use a project alias such as `type StepResult = anyhow::Result<()>;`, and turn a failed check into an error with `anyhow::ensure!`.
- Prefer Cucumber Expressions (`expr = "{int} tracks"`) over `regex =`. If you use a regex, anchor it with `^` and `$`.
- Capture closed sets as typed parameters, not strings: derive `cucumber::Parameter` with `#[param(name = "state", regex = "hungry|satiated")]` on an enum that implements `FromStr`. This is the same parse-at-the-boundary rule as the enums section of `SKILL.md`.
- Keep each step atomic. A step that does two actions ("I log in and open settings") is a conjunction step; split it and join with `And`.
- Step bodies call the library code. Do not put business logic in step definitions.

## Scenarios

- Write declarative scenarios: describe what the system does, not which inputs or clicks produce it. Test each line with "will this wording change if the implementation changes?" If yes, rewrite it.
- Use `Background` for setup that every scenario of a feature shares, in place of a global `before` hook. Only the last registered `before` or `after` hook runs.
- Use `Scenario Outline` with `Examples` for the same behavior across a table of inputs. Use `Rule` to group scenarios under one business rule.
- Each scenario must pass alone and in any order. Scenarios run concurrently (64 at once by default).

## Runner

```rust
use cucumber::World as _;

fn main() {
    // cargo-nextest lists tests with `--list`; Cucumber does not support it.
    if std::env::args().any(|a| a == "--list") {
        return;
    }
    futures::executor::block_on(
        SyncWorld::cucumber()
            .fail_on_skipped()
            .run_and_exit("features/sync"),
    );
}
```

- Call `fail_on_skipped()` so that a step with no match fails the run. Tag scenarios you intentionally leave unimplemented with `@allow.skipped`.
- Use `run_and_exit` so a failure sets a non-zero exit code. `run` only returns the writer and does not fail the process.
- Use `futures::executor::block_on` when steps are sync or use only simple futures. Use `#[tokio::main]` only when a step needs the tokio runtime.
- Tag scenarios that change process-wide state (environment variables, current directory, a shared file) with `@serial`, or run the target with `--concurrency=1`.
- Use `filter_run` (or `--tags`) to exclude work in progress, for example `!sc.tags.iter().any(|t| t == "wip")`.
- Add custom CLI options with a `#[derive(cli::Args)]` struct, `cli::Opts::<_, _, _, Custom>::parsed()`, and `.with_cli(opts)`. CLI options override settings made in code.
- cargo-nextest does not run Cucumber targets and the maintainers do not plan native support ([#370](https://github.com/cucumber-rs/cucumber/issues/370)). Exit early on `--list` so nextest skips the target, and run the targets with `cargo test`. The other option is the OpenFeature form: call `World::cucumber().run(...)` inside a `#[tokio::test]` and keep the default harness.

## Flaky scenarios

A scenario that passes only on retry has failed (see [verification.md](verification.md)). Use `@retry(n)` or `@retry(n).after(dur)`, or `--retry`, `--retry-after`, and `--retry-tag-filter`, only for scenarios that touch a real external system, and record why on the tag. `@retry(3).after(1s)` ignores the CLI retry options; plain `@retry` takes them.

## Output and CI

- The default writer prints readable output. `-vv` adds the World on a failed step, and `-vvv` adds the doc string.
- `cargo test --workspace` runs `harness = false` targets, so the existing check command needs no change.
- For CI reports, enable the `output-junit` feature and use `writer::JUnit::new(file, 0)` with `.with_writer(...)`, then upload the XML.
- For IDE output, enable the `libtest` feature and use `writer::Libtest::or_basic()`. It adds `--format=json`. Timings are correct only with `--concurrency=1`. In a workspace, set `CARGO_WORKSPACE_DIR` in `.cargo/config.toml` so jump-to-definition works.

## Review checklist

- Each domain has its own feature directory, `[[test]]` target, World, and step file.
- Steps return `Result` and use `?` and `ensure!`, not `unwrap`, `expect`, or `panic!`.
- The runner calls `fail_on_skipped()` and `run_and_exit`.
- Scenarios that change shared state carry `@serial`.
- Scenario wording does not name implementation details.
- Unit, property, and fuzz tests stayed as `#[test]`; only behavior-level integration tests moved to features.
