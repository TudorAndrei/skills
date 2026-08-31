---
name: postgres-ops
description: Diagnose and improve live PostgreSQL systems. Use for slow queries, query plans, locks, connection pressure, autovacuum, bloat, migrations, partitioning, scaling, and extension selection.
compatibility: >-
  Read-only advisor. Needs database access only for diagnostics; the audit and investigation SQL is
  safe on supported PostgreSQL versions. Never run production-changing SQL without explicit user
  approval, and do not author migration files.
metadata:
  version: "2.0.0"
  mode: advisor (read-only; diagnoses and recommends, does not write migrations)
  audience: self-hosted PostgreSQL (full superuser / can install extensions)
  source: "Operational themes adapted from Hatchet's The startup's Postgres survival guide (2026-07-22)"
---

# PostgreSQL Operations & Modernization

Two jobs against a database that already exists: work out **why it hurts now**, and work out **what
it should adopt next**. They share an intake, a set of guardrails, and a bias toward evidence over
generic tuning advice, so they live together here.

This skill is a **read-only advisor**. Inspect, reason, and hand back a diagnosis or a prioritized
report. Illustrative SQL is good — it shows the user what a change looks like — but frame it as an
example, not a ready-to-run migration. The user or a follow-up implementation step owns rollout.

**Not this skill:** designing a new schema from scratch, or standing up pgvector / PostGIS /
TimescaleDB / hybrid search for the first time. That is greenfield design work — use the `postgres`
skill instead. Come back here once it is running and you need to operate or modernize it.

## Pick the mode

| The user is saying                                                   | Mode                    |
| -------------------------------------------------------------------- | ----------------------- |
| "This query got slow", "we're deadlocking", "disk keeps growing"     | **Diagnose**            |
| "This migration is scary", "how do I add this column safely"         | **Diagnose**            |
| "What could be better?", "how do we speed this up generally?"        | **Modernize**           |
| "Which extension should I use for X?", "what does upgrading get us?" | **Modernize**           |
| A specific pain _and_ a general "what else" — or you can't tell      | Intake first, then both |

The modes are not exclusive. A bloat complaint is a Diagnose intake that often ends in a Modernize
recommendation (`pg_repack`, partitioning, `fillfactor`). Run the diagnosis, then say what structural
change would stop it recurring.

## Shared ground rules

- **Establish ground truth before prescribing.** PostgreSQL major version, deployment type, workload
  shape, table sizes and write rate, availability requirement, replication topology, what extensions
  are already installed, and a rollback path. Ask for what's missing, but make useful progress with
  clearly labelled assumptions.
- **Respect the version.** Never present a feature the user's version lacks as available today. If
  it's compelling, surface it as a reason to upgrade.
- **Label every statement** you supply as **read-only**, **production-changing**, or **requires a
  maintenance window**.
- **No universal numbers.** Don't present a configuration value or batch size as correct in the
  abstract; explain the workload-dependent tradeoff and how to measure its effect.
- **Rollout safety is part of the advice even though you don't apply it.** Index builds go
  `CONCURRENTLY`; bloat removal prefers `pg_repack`/`pg_squeeze` over `VACUUM FULL` on a live table;
  partitioning an existing large table is a migration, not a switch — say so.

Read [`references/operational-queries.md`](references/operational-queries.md) for diagnostic SQL and
safe patterns, or [`references/audit.md`](references/audit.md) for the full read-only deployment
inventory to hand the user.

## Mode A — Diagnose

Turn a vague production concern into an evidence-based diagnosis and a safe rollout plan. The goal is
not to force every query through an index: it is to keep latency, locks, connection use, and
maintenance work within the database's actual capacity.

### Classify the failure mode

| Symptom or goal                             | Start here                                                                                                             |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| A single query is slow                      | Obtain the query and `EXPLAIN`/`EXPLAIN ANALYZE`; examine estimates, joins, filters, sort, and rows touched.           |
| A deploy or migration may stall writes      | Identify lock-taking statements; use an expand/contract rollout and non-blocking DDL where appropriate.                |
| CPU, I/O, or write throughput is saturated  | Check connection churn, query round trips, batch shape, indexes maintained per write, locks, and vacuum.               |
| Disk use or latency rises over time         | Inspect dead tuples, vacuum/analyze history, long transactions, table/index bloat, and transaction-ID age.             |
| Workers duplicate work or block one another | Consider a short transaction using `FOR UPDATE SKIP LOCKED`; define retry, lease, and failure semantics.               |
| Historical data grows without bound         | Evaluate time/range partitioning only when retention, pruning, and operational benefits outweigh added complexity.     |
| A huge table must be copied or reshaped     | Plan dual writes or a trigger mirror, idempotent batches, validation, and a cutover; avoid a single giant transaction. |

### Investigate before changing anything

1. **Capture the query and its context.** Note parameter values, frequency, p50/p95 latency,
   result cardinality, table/index sizes, write rate, and whether the slowness is recent.
2. **Inspect the plan.** Use `EXPLAIN` on production by default. `EXPLAIN ANALYZE` executes the
   query, so use it only with a representative, bounded query when the user accepts that risk.
   Compare estimated and actual rows, scan type, join order, sort/hash spills, buffer reads, and
   total time.
3. **Inspect system state.** Look for long transactions, lock waits, active autovacuum, dead
   tuples, stale analyze history, connection saturation, and the biggest/most frequently scanned
   relations.
4. **State the likely cause and confidence.** Distinguish evidence from hypotheses. A sequential
   scan is not automatically a defect: for a small table or a query returning a large fraction of
   rows, it can be the cheaper plan.
5. **Propose the least risky remedy first.** Examples: correct an accidental broad predicate,
   update stale statistics, reduce round trips, or add the narrowly matched index. Escalate to
   partitioning, a rewrite, or configuration tuning only when evidence warrants it.

### Query and schema design

- Model the expected reads and writes before finalizing a schema. Identify high-read/high-write
  tables, common filters, joins, sorts, and frequently updated columns.
- Use a primary key on every table. Prefer `timestamptz` for real-world event times. Choose identity
  columns or UUIDs according to workload and distribution needs.
- Treat join predicates like filter predicates: join on primary keys where the model permits, and
  ensure the other side has an appropriate index. Do not add redundant indexes blindly.
- Design a compound index around the real access path. Put equality filters before the ordering
  keys; put the `ORDER BY` columns at the end and match their order/direction when it matters.
  Verify it with the actual plan and account for the write and storage cost of the index.
- Avoid using an ORM abstraction as a reason to skip plan inspection. Use parameterized SQL or the
  ORM's escape hatch for the small number of performance-critical statements.

### Writes, locks, and connections

- Keep transactions short. Never hold a row lock while waiting on a network call, user input, or a
  slow computation.
- Lock only the rows needed for the operation and consistently acquire multiple resources in the
  same order to reduce deadlock risk.
- Reuse long-lived connections through an application pool; for many short-lived application
  instances, use a properly configured external pooler such as PgBouncer. Connection storms waste
  CPU/memory and can amplify lock problems.
- For high-volume inserts/updates, reduce per-query overhead with bounded batches. Pick a batch size
  from measurements; huge batches can lengthen transactions, spike WAL, and delay vacuum.
- Record idempotency and retry behavior for all writes. Batching improves throughput only if retries
  cannot silently duplicate business effects.

### Online migrations

Use an **expand → backfill → validate → switch → contract** sequence for changes that can affect
live writers or readers:

1. Add compatible schema elements (nullable column, new table, or new index) without changing old
   reads/writes.
2. Deploy code that writes both representations when needed.
3. Backfill in small, resumable, primary-key/range batches. Commit each batch and throttle based on
   replica lag, locks, WAL, and latency.
4. Validate correctness and counts; add or validate constraints separately.
5. Switch reads, observe, then remove old code/data only after a defined retention window.

For an existing large table, build indexes with `CREATE INDEX CONCURRENTLY`; remember that it cannot
run inside a transaction block and can still fail or consume significant I/O. Treat `ALTER TABLE` as
a lock-risk review point. Add large-table checks or foreign keys using `NOT VALID`, then validate in
a separate controlled step when supported by the desired constraint type. Include lock/statement
timeouts, an abort condition, monitoring, and a rollback or forward-fix path in every runbook.

### Planner, statistics, and scans

- The planner chooses from imperfect statistics. Large gaps between estimated and actual rows often
  point to stale statistics, correlated predicates, skew, or a query shape that hides selectivity.
- Run or tune `ANALYZE` only after checking table churn and maintenance history. More timely
  autovacuum can also keep statistics current.
- Accept a sequential scan when it is demonstrably cheaper. An index scan has overhead and may lose
  when the query reads much of the table.
- Do not use planner-hint hacks as a first response. Prefer correcting statistics, simplifying the
  query, or adding an index that matches a stable access pattern.

### Autovacuum, bloat, and transaction age

On write-heavy tables, autovacuum is capacity work, not background noise. Dead tuples accumulate
after updates/deletes until old transactions no longer need them; long-running transactions can
prevent cleanup. Monitor vacuum progress, dead-tuple growth, analyze freshness, disk growth, and
transaction-ID age before tuning thresholds or worker settings.

Avoid `VACUUM FULL` as an ad-hoc production repair: it requires an exclusive lock. For existing
bloat, evaluate an online-repacking approach such as `pg_repack` where supported, with a tested
maintenance window and backup/restore plan. For index bloat, consider `REINDEX INDEX CONCURRENTLY`
when applicable. Prevent recurrence by fixing transaction duration, table-specific autovacuum
settings, excessive indexes, and update patterns.

### Concurrency and data-lifecycle patterns

**Work queues and leases.** `FOR UPDATE SKIP LOCKED` lets concurrent workers claim distinct eligible
rows without waiting on each other. Keep the claim transaction short and make the state machine
explicit: eligibility, lease timeout, heartbeat/renewal, success, retry/backoff, poison jobs, and
crash recovery. It is a coordination primitive, not a complete queue design — if the user is building
the whole queue, `pgmq` is a Modernize recommendation worth naming.

**Partitioning.** Propose partitioning for a clearly bounded partition key, usually time-oriented
retention data or a large table whose maintenance benefits from independent partitions. Confirm that
common predicates enable partition pruning, that cross-partition uniqueness/queries behave as needed,
and that the team can automate partition creation, indexes, retention, and monitoring. Do not use it
merely to mask a missing index or stale statistics.

**Large table moves.** Never advise copying a large live table in one multi-hour transaction. Prefer
an idempotent batched backfill outside one global transaction. If writes must continue, mirror new
changes with carefully tested application dual-writes or triggers; protect the target with a
primary/unique key so replayed batches are safe. Reconcile source and target before cutover, then
retain a rollback window.

## Mode B — Modernize

Take a deployment that already works and make it faster, leaner, and more capable by adopting the
right **extensions** and **version-gated core features**. The audience is **self-hosted** Postgres
where the user controls the box and can install any extension — so recommendations are not
constrained by managed-platform allowlists.

Most deployments run on defaults from whenever they were first set up: an old major version, no
`pg_stat_statements`, generic `zlib` TOAST, and hand-rolled solutions for things a mature extension
does better (a `cron` sidecar instead of `pg_cron`, a Python worker polling a table instead of
`pgmq`, brute-force `LIKE` search instead of `pg_search`/`pg_trgm`, a separate vector database
instead of `pgvector`). The highest-leverage move for such a system is usually **not** rewriting
application queries — it's to (a) get on a modern major version, (b) turn on the core features that
version already ships, and (c) replace bespoke machinery with something battle-tested.

### 1. Intake — establish the ground truth

Recommendations that ignore the actual version, workload, and current pain are noise. Ask the user,
or better, give them the queries in [`references/audit.md`](references/audit.md) to run and paste
back. Establish:

- **Major version** (`SHOW server_version;`). This gates everything — a feature that ships in 16 is
  irrelevant advice for a 13 cluster except as a reason to upgrade.
- **Workload shape**: OLTP, analytics/reporting, time-series/metrics, search, geospatial, mixed,
  multi-tenant SaaS? This determines which use-case extensions matter.
- **Current pain**: slow queries, bloat, disk growth, bad plans, autovacuum falling behind,
  connection exhaustion, a use case that feels bolted-on (search, vector, queue, cron).
- **What's already installed**: `SELECT * FROM pg_extension;` — so you recommend additions, not
  duplicates.
- **Scale**: rough table sizes, row counts, write rate, and whether the biggest tables are naturally
  time-ordered or append-mostly (this decides partitioning and BRIN).

If the user just wants a general "what could be better," run the full audit and let the data pick the
priorities.

### 2. Map pain and use cases to recommendations

Two catalogs drive the recommendations. Read the relevant one before recommending:

- [`references/extensions.md`](references/extensions.md) — extensions grouped by use case
  (AI/vector, search, time-series, geospatial, queues/jobs, observability & tuning,
  bloat/maintenance, pooling, scale-out, analytics, security/audit, FDW/lakehouse). Each entry: what
  it's for, when it wins over doing it by hand or with a separate service, and the main tradeoff.
- [`references/features.md`](references/features.md) — core features organized by the major version
  that introduced them, labeled for performance impact, plus version-independent wins
  (covering/partial/BRIN indexes, native partitioning, extended statistics, HOT/fillfactor,
  `CONCURRENTLY`, connection pooling).

Match, don't spray. A read-heavy analytics box that already has `pg_stat_statements` doesn't need a
lecture on `pgmq`; it needs BRIN indexes, extended statistics, maybe columnar via Citus or a DuckDB
FDW, and a look at whether it's still on a version without parallel-hash-join improvements.

### 3. Prioritize by leverage

Rank recommendations, most impactful first, using this rough ordering:

1. **Get on a supported, modern major version.** Everything downstream depends on it, and each
   recent release is largely free performance (planner, vacuum, I/O). If they're out of support or
   more than ~3 majors behind, this is usually item #1.
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

### 4. Extra guardrails for recommendations

- **Extension maturity is a real cost.** Core and widely-deployed extensions
  (`pg_stat_statements`, `pg_trgm`, `pgvector`, PostGIS, `pg_partman`, `pg_repack`, PgBouncer) are
  safe defaults. Younger or heavier ones (columnar engines, lakehouse FDWs, planner-hint tools)
  belong behind an explicit tradeoff note. Say which tier a recommendation is in.
- **Licensing matters for self-hosted-at-scale.** Flag non-standard licenses where relevant (e.g.
  TimescaleDB's community edition, Citus specifics, ParadeDB components) so the user isn't surprised.
- **Don't recommend against the workload.** BRIN on a randomly-ordered table, columnar for OLTP, or a
  queue extension for a read-only reporting replica are anti-recommendations. The catalogs note where
  each choice loses.

## Report formats

Use the template matching the mode, unless the user asks for a narrower answer.

### Diagnose

```markdown
# PostgreSQL Assessment: <short title>

## What we know

- Environment, version, workload, scale, and evidence provided.

## Likely cause

- Finding, confidence, and the plan/metric that supports it.

## Recommended next steps

1. <lowest-risk observation or change> — why it comes first.
2. <next step> — expected benefit and tradeoff.

## Safe rollout

- Preconditions, SQL/commands (label read-only vs mutating), lock/transaction considerations,
  monitoring signals, abort threshold, and rollback/forward-fix plan.

## Verification

- Exact metric, query-plan property, data-integrity check, and observation period that define success.

## Open questions

- Facts that could change the recommendation.
```

### Modernize

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

Every recommendation must carry a _why_ and a _tradeoff_. A report that's just a list of extensions
is easy to write and useless to act on; the value is the judgment about what's worth it for _this_
deployment.

## Reference files

- [`references/operational-queries.md`](references/operational-queries.md) — diagnostic SQL and safe
  operational patterns (plans, locks, bloat, vacuum, batching, `SKIP LOCKED`). Diagnose mode.
- [`references/audit.md`](references/audit.md) — copy-paste read-only SQL to inventory a running
  deployment; hand to the user during intake. Safe in production.
- [`references/extensions.md`](references/extensions.md) — extensions by use case. Read before
  recommending any extension.
- [`references/features.md`](references/features.md) — core features by version, plus
  version-independent performance wins.

## Scope

This skill does not replace PostgreSQL's version-specific documentation or an incident response
process. The operational half distills Hatchet's _The startup's Postgres survival guide_
(2026-07-22) — schema/query fundamentals, lock-aware migrations, connection management,
planner/statistics reasoning, batching, vacuum/bloat management, `SKIP LOCKED`, partitioning, safe
large-table moves — and adds explicit production guardrails.
