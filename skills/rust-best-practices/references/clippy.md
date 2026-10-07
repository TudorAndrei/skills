# Strict Clippy Config

Source: https://namtao.com/rust

## Cargo.toml

```toml
[lints.clippy]
pedantic = { level = "deny", priority = -1 }  # um, actually
nursery = { level = "deny", priority = -1 }   # beta lints
# deny panics
unwrap_used = "deny"
expect_used = "deny"
indexing_slicing = "deny"
arithmetic_side_effects = "deny"
unreachable = "deny"
unimplemented = "deny"
unchecked_time_subtraction = "deny"
todo = "deny"
string_slice = "deny"
panic_in_result_fn = "deny"
panic = "deny"
exit = "deny"
as_conversions = "deny"

[lints.rust]
unsafe_op_in_unsafe_fn = "deny"
```

In a workspace, put the tables in the root `Cargo.toml` as `[workspace.lints.clippy]` and `[workspace.lints.rust]`, and add this to each member:

```toml
[lints]
workspace = true
```

## clippy.toml

Put this next to the root `Cargo.toml`. It keeps tests readable while production code stays strict.

```toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
allow-panic-in-tests = true
allow-indexing-slicing-in-tests = true
```

## Why each setting

- `priority = -1` on the groups makes the groups apply first, so single-lint entries can override them. Without it, the order is undefined and Clippy's `lint_groups_priority` lint reports an error.
- `pedantic`: stricter style and correctness lints. Expect noise; allow single lints locally with a reason instead of disabling the group.
- `nursery`: lints still in development. They can give false positives. Allow a noisy one by name with a comment.
- `unwrap_used`, `expect_used`, `panic`, `unreachable`, `unimplemented`, `todo`: forbid panicking shortcuts. Return `Result` or `Option` and propagate with `?`.
- `indexing_slicing`, `string_slice`: `v[i]` and `&s[a..b]` panic when out of range or not on a char boundary. Use `get`, `get_mut`, `split_at_checked`, iterators, or pattern matching.
- `arithmetic_side_effects`: `+`, `-`, `*` can overflow. Use `checked_*`, `saturating_*`, or `wrapping_*` to state the intent.
- `unchecked_time_subtraction`: `Instant - Duration` and `Duration - Duration` can panic on underflow. Use `checked_sub`.
- `panic_in_result_fn`: a function that returns `Result` must not also panic.
- `exit`: `std::process::exit` skips destructors. Return an exit code from `main` instead.
- `as_conversions`: `as` truncates and changes sign silently. Use `From`, `TryFrom`, or `try_into`.
- `unsafe_op_in_unsafe_fn` (rustc lint): each unsafe operation inside an `unsafe fn` still needs its own `unsafe` block, so the unsafe surface stays visible for review and Miri.

## Applying to an existing codebase

1. Add the config, then run `cargo clippy --all-targets --all-features` and count the findings.
2. If the count is large, set `"warn"` first and fix module by module, then change to `"deny"`.
3. Allow a lint locally only with a reason, for example `#[expect(clippy::indexing_slicing, reason = "index checked above")]`. Prefer `#[expect]` over `#[allow]` so the attribute fails when it is no longer needed.
4. If Clippy reports an unknown lint, the toolchain is older than the lint. Update the toolchain or remove that line and tell the user.
