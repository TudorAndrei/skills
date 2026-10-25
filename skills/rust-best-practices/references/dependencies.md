# Dependencies

Sources: https://github.com/hexuria/impeccable-rust (MIT), https://github.com/morganlinton/BeautifulRust (MIT)

## Hygiene

Every dependency costs compile time, binary size, and supply-chain exposure, including its `build.rs` and proc macros.

- Use version ranges (`"1"`, `"1.4"`), never `"*"` or a needless `"="`. Commit `Cargo.lock` for binaries.
- Find duplicate versions with `cargo tree --duplicates` and unused dependencies with `cargo udeps`.
- Keep features additive and bare-named (`std`, `serde`, `alloc`, `test-util`). A feature never removes or changes a public item; do not feature-gate struct fields or trait methods. Put mocks and fakes behind `test-util`, and `serde` impls behind `serde`.
- Do not run code before `main()` (no `ctor`-style crates).

## Supply chain

1. Track the complete dependency closure of every deployment that matters. Build shipped binaries with `cargo auditable build`, so each binary carries its dependency list in a linker section, and scan the binaries (`cargo audit bin`, Trivy, Grype, or osv-scanner), not only the lockfile.
2. Join against known issues: RUSTSEC through `cargo deny check` or `cargo audit`.
3. Vet for unknown issues with `cargo-vet`, using public or internal audits. `cargo vet init` exempts every current dependency, so a new setup gates only new dependencies until imported and local audits shrink the exemptions. Say so when you add it.
4. Scan `.github/workflows` with `zizmor` for template injection, excessive permissions, unpinned actions, and persisted credentials.

Be able to answer operational questions such as "which deployed units still run this vulnerable transitive crate?".

## Stagnation is a choice

Every skipped upgrade cycle raises the cost of the next one. Surface lag instead of deferring it silently:

- Loud reminders: Dependabot or Renovate for updates; RUSTSEC unmaintained advisories through `cargo deny`, or Renovate's `abandonmentThreshold`, for dead crates (Dependabot does not flag abandonment).
- Auto-merge dependency bump PRs that pass tests.
- Budget maintenance time.
- Upstream fixes instead of keeping long-lived forks.
- Wrap unstable dependencies behind a stable internal facade.
- Treat rustc and edition lag like crate lag.
