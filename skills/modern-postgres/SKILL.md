---
name: modern-postgres
description: >-
  Audits a self-hosted PostgreSQL deployment and returns a prioritized modernization report: which
  extensions to adopt (pgvector, TimescaleDB, pg_partman, pg_search, PostGIS, pg_repack,
  pg_stat_monitor, hypopg, PgBouncer/pgcat, Citus, pgmq, pgaudit) and which version-gated core
  features to turn on (LZ4/zstd compression, covering/BRIN indexes, native partitioning, MERGE,
  JSON_TABLE, async I/O, extended statistics, incremental backup). Read-only: recommends, does not
  write migrations. Use whenever the user wants to improve, modernize, or speed up a running Postgres
  database, asks which Postgres extension fits a use case (vector/AI search, time-series, geospatial,
  queues, sharding, full-text), asks what features their Postgres version unlocks, is planning a
  major-version upgrade, or is fighting bloat, slow queries, bad plans, autovacuum, or partitioning
  at scale.
metadata:
  version: "1.0.0"
  audience: self-hosted PostgreSQL (full superuser / can install extensions)
  mode: advisor (read-only; recommends, does not write migrations)
---

# Modern PostgreSQL Advisor

Take a PostgreSQL deployment that already works and make it faster, leaner, and more capable by
adopting the right **extensions** and **version-gated core features**. The audience is **self-hosted**
Postgres where you control the box and can install any extension — so recommendations are not
constrained by managed-platform allowlists.

This is a **read-only advisor**. Inspect, reason, and hand back a prioritized report with rationale
and tradeoffs. Do **not** author migration files or apply changes. Illustrative SQL in the report is
fine (it shows the user _what_ a change looks like), but frame it as an example, not a ready-to-run
migration — the user or a follow-up implementation step owns rollout.

## Why this exists

Most Postgres deployments are running on defaults from whenever they were first set up: an old major
version, no `pg_stat_statements`, generic `zlib` TOAST, hand-rolled solutions for things a mature
extension does better (a `cron` sidecar instead of `pg_cron`, a Python worker polling a table instead
of `pgmq`, brute-force `LIKE` search instead of `pg_search`/`pg_trgm`, a separate vector DB instead of
`pgvector`). The single highest-leverage thing you can do for such a system is usually **not** rewrite
application queries — it's to (a) get on a modern major version, (b) turn on the core features that
version already ships, and (c) replace bespoke machinery with a battle-tested extension. That is what
this skill optimizes for.

## The workflow

Work through these phases. Don't skip the intake — recommendations that ignore the actual version,
workload, and current pain are noise.

### 1. Intake — establish the ground truth

You cannot give good advice without these facts. Ask the user, or (better) give them the audit
queries in `references/audit.md` to run and paste back. Establish:

- **Major version** (`SHOW server_version;`). This gates everything — a feature that ships in 16 is
  irrelevant advice for a 13 cluster except as a reason to upgrade.
- **Workload shape**: OLTP, analytics/reporting, time-series/metrics, search, geospatial, mixed,
  multi-tenant SaaS? This determines _which_ use-case extensions matter.
- **Current pain**: slow queries, bloat, disk growth, bad plans, autovacuum falling behind,
  connection exhaustion, a use case that feels bolted-on (search, vector, queue, cron).
- **What's already installed**: `SELECT * FROM pg_extension;` — so you recommend additions, not
  duplicates.
- **Scale**: rough table sizes, row counts, write rate, and whether the biggest tables are
  naturally time-ordered or append-mostly (this decides partitioning and BRIN).

If the user just wants a general "what could be better," run the full audit and let the data pick the
priorities.

### 2. Map pain and use cases to recommendations

Two catalogs drive the recommendations. Read the relevant one before recommending:

- **`references/extensions.md`** — extensions grouped by use case (AI/vector, search, time-series,
  geospatial, queues/jobs, observability & tuning, bloat/maintenance, pooling, scale-out, analytics,
  security/audit, FDW/lakehouse). Each entry: what it's for, when it wins over doing it by hand or
  with a separate service, and the main tradeoff.
- **`references/features.md`** — core features organized by the major version that introduced them,
  plane-labeled for performance impact, plus version-independent wins (covering/partial/BRIN indexes,
  native partitioning, extended statistics, HOT/fillfactor, `CONCURRENTLY`, connection pooling).

Match, don't spray. A read-heavy analytics box that already has `pg_stat_statements` doesn't need a
lecture on `pgmq`; it needs BRIN indexes, extended statistics, maybe columnar via Citus or a DuckDB
FDW, and a look at whether it's still on a version without parallel-hash-join improvements.

### 3. Prioritize by leverage

Rank recommendations, most impactful first, using this rough ordering:

1. **Get on a supported, modern major version.** Everything downstream depends on it, and each recent
   release is largely free performance (planner, vacuum, I/O). If they're on something out of
   support or more than ~3 majors behind, this is usually item #1.
2. **Turn on observability first** (`pg_stat_statements`, and consider `pg_stat_monitor` /
   `auto_explain`). You can't prioritize query work blind, and it's near-zero risk.
3. **Free structural wins**: LZ4 TOAST compression, WAL compression, `fillfactor`/HOT for
   update-heavy tables, extended statistics for correlated predicates, covering (`INCLUDE`) and BRIN
   indexes. Low risk, often large.
4. **Replace bespoke machinery with the right extension** for the workload's core use case
   (vector/search/time-series/queue/geo). High value where it applies.
5. **Operational hardening**: connection pooling, `pg_repack` for existing bloat, `pg_partman` +
   native partitioning for unbounded tables, `pg_cron` for in-DB scheduling.
6. **Scale-out / specialized** (Citus, columnar, lakehouse FDWs): only when single-node headroom is
   genuinely the limit.

### 4. Deliver the report

Use the structure below. Every recommendation must carry a _why_ and a _tradeoff_ — a modernization
report that's just a list of extensions is easy to write and useless to act on. The value is the
judgment about what's worth it for _this_ deployment.

## Report structure

Use this template:

```markdown
# PostgreSQL Modernization Report

## Deployment summary

- Version, workload, scale, notable current pain (2–5 bullets from intake).

## Top recommendations (prioritized)

For each, in priority order:

### N. <Short title> — <impact: high/med/low> · <effort: low/med/high> · <risk: low/med/high>

- **What**: the change (extension to adopt / feature to enable / version to move to).
- **Why here**: the specific signal in _this_ deployment that motivates it (a slow query, a bloated
  table, a bolted-on use case, a missing-in-old-version feature).
- **Tradeoff / cost**: what it costs — extension maturity, operational surface, rebuild/lock during
  rollout, licensing, added moving part.
- **How (sketch)**: a short illustrative snippet or pointer. Note rollout safety
  (`CREATE INDEX CONCURRENTLY`, `pg_repack` vs `VACUUM FULL`, version guard) but do not write a
  migration file.

## Version upgrade note (if applicable)

- Current → recommended target, and the 3–5 features they'd unlock that matter for their workload.

## Deferred / not recommended

- Things they might expect on the list but that don't fit (with one line why), so the omission is
  deliberate, not an oversight.
```

## Guardrails

- **Respect the version.** Never recommend enabling a feature the user's version doesn't have as if
  it's available today. If it's compelling, surface it as a _reason to upgrade_ in the version note.
- **Extension maturity is a real cost.** Core and widely-deployed extensions (`pg_stat_statements`,
  `pg_trgm`, `pgvector`, `PostGIS`, `pg_partman`, `pg_repack`, PgBouncer) are safe defaults. Younger
  or heavier ones (columnar engines, lakehouse FDWs, planner-hint tools) belong behind an explicit
  "here's the tradeoff" note. Say which tier a recommendation is in.
- **Licensing matters for self-hosted-at-scale.** Flag non-standard licenses where relevant (e.g.
  TimescaleDB's community edition, Citus specifics, ParadeDB components) so the user isn't surprised.
- **Don't recommend against the workload.** BRIN on a randomly-ordered table, columnar for OLTP, or a
  queue extension for a read-only reporting replica are anti-recommendations. The catalogs note where
  each choice _loses_.
- **Rollout safety is part of the advice, even though you don't apply it.** Index builds should be
  `CONCURRENTLY`; bloat removal should prefer `pg_repack`/`pg_squeeze` over `VACUUM FULL` on live
  tables; partitioning an existing large table is a migration, not a switch — say so.

## Reference files

- `references/extensions.md` — extensions by use case (read before recommending any extension).
- `references/features.md` — core features by version + version-independent performance wins.
- `references/audit.md` — copy-paste SQL to inventory a running deployment (hand to the user for the
  intake phase; read-only, safe to run in production).
