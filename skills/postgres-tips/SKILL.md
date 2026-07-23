---
name: postgres-tips
description: >-
  Diagnose, design, and safely operate production PostgreSQL systems using practical survival
  patterns for slow queries, indexes, locks, migrations, connection pressure, high-write tables,
  autovacuum, bloat, queues, partitioning, and large data moves. Use this whenever a user is
  troubleshooting or planning changes to a live Postgres database, even if they ask only about a
  slow query, a migration, a background worker, or disk growth. Prefer evidence from plans and
  system views, and give lock-aware, rollback-aware guidance rather than generic tuning advice.
compatibility: Requires PostgreSQL access only for live diagnostics; safe read-only SQL works on supported PostgreSQL versions. Do not run production-changing SQL without explicit user approval.
metadata:
  version: "1.0.0"
  source: "Adapted from Hatchet's The startup's Postgres survival guide (2026-07-22)"
  mode: diagnose-and-plan
---

# PostgreSQL Survival Tips

Use this skill to turn a vague production concern into an evidence-based diagnosis and a safe
rollout plan. The goal is not to force every query through an index: it is to keep latency,
locks, connection use, and maintenance work within the database's actual capacity.

Treat all changes to a live database as potentially disruptive. Establish the PostgreSQL version,
deployment type, table size/write rate, availability requirement, replication topology, and a
rollback path before proposing executable DDL or configuration changes.

## Start with the workload and the failure mode

Classify the request before prescribing a fix:

| Symptom or goal                             | Start here                                                                                                             |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| A single query is slow                      | Obtain the query and `EXPLAIN`/`EXPLAIN ANALYZE`; examine estimates, joins, filters, sort, and rows touched.           |
| A deploy or migration may stall writes      | Identify lock-taking statements; use an expand/contract rollout and non-blocking DDL where appropriate.                |
| CPU, I/O, or write throughput is saturated  | Check connection churn, query round trips, batch shape, indexes maintained per write, locks, and vacuum.               |
| Disk use or latency rises over time         | Inspect dead tuples, vacuum/analyze history, long transactions, table/index bloat, and transaction-ID age.             |
| Workers duplicate work or block one another | Consider a short transaction using `FOR UPDATE SKIP LOCKED`; define retry, lease, and failure semantics.               |
| Historical data grows without bound         | Evaluate time/range partitioning only when retention, pruning, and operational benefits outweigh added complexity.     |
| A huge table must be copied or reshaped     | Plan dual writes or a trigger mirror, idempotent batches, validation, and a cutover; avoid a single giant transaction. |

Ask for missing facts, but make useful progress with clearly labelled assumptions. Read
[`references/operational-queries.md`](references/operational-queries.md) when you need diagnostic
SQL or a concrete safe pattern.

## Investigate before changing anything

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

## Query and schema design

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

## Writes, locks, and connections

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

## Online migrations

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

## Planner, statistics, and scans

- The planner chooses from imperfect statistics. Large gaps between estimated and actual rows often
  point to stale statistics, correlated predicates, skew, or a query shape that hides selectivity.
- Run or tune `ANALYZE` only after checking table churn and maintenance history. More timely
  autovacuum can also keep statistics current.
- Accept a sequential scan when it is demonstrably cheaper. An index scan has overhead and may lose
  when the query reads much of the table.
- Do not use planner-hint hacks as a first response. Prefer correcting statistics, simplifying the
  query, or adding an index that matches a stable access pattern.

## Autovacuum, bloat, and transaction age

On write-heavy tables, autovacuum is capacity work, not background noise. Dead tuples accumulate
after updates/deletes until old transactions no longer need them; long-running transactions can
prevent cleanup. Monitor vacuum progress, dead-tuple growth, analyze freshness, disk growth, and
transaction-ID age before tuning thresholds or worker settings.

Avoid `VACUUM FULL` as an ad-hoc production repair: it requires an exclusive lock. For existing
bloat, evaluate an online-repacking approach such as `pg_repack` where supported, with a tested
maintenance window and backup/restore plan. For index bloat, consider `REINDEX INDEX CONCURRENTLY`
when applicable. Prevent recurrence by fixing transaction duration, table-specific autovacuum
settings, excessive indexes, and update patterns.

## Concurrency and data-lifecycle patterns

### Work queues and leases

`FOR UPDATE SKIP LOCKED` lets concurrent workers claim distinct eligible rows without waiting on
each other. Keep the claim transaction short and make the state machine explicit: eligibility,
lease timeout, heartbeat/renewal, success, retry/backoff, poison jobs, and crash recovery. It is a
coordination primitive, not a complete queue design.

### Partitioning

Propose partitioning for a clearly bounded partition key, usually time-oriented retention data or a
large table whose maintenance benefits from independent partitions. Confirm that common predicates
enable partition pruning, that cross-partition uniqueness/queries behave as needed, and that the
team can automate partition creation, indexes, retention, and monitoring. Do not use it merely to
mask a missing index or stale statistics.

### Large table moves

Never advise copying a large live table in one multi-hour transaction. Prefer an idempotent batched
backfill outside one global transaction. If writes must continue, mirror new changes with carefully
tested application dual-writes or triggers; protect the target with a primary/unique key so replayed
batches are safe. Reconcile source and target before cutover, then retain a rollback window.

## Response format

For diagnosis or planning work, use this structure unless the user asks for a narrower answer:

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

When supplying SQL, mark each statement **read-only**, **production-changing**, or **requires a
maintenance window**. Do not present a configuration value or batch size as universal; explain the
workload-dependent tradeoff and how to measure its effect.

## Source and scope

This skill distills the operational themes of Hatchet's _The startup's Postgres survival guide_
(2026-07-22): good schema/query fundamentals, lock-aware migrations, connection management,
planner/statistics reasoning, batching, vacuum/bloat management, `SKIP LOCKED`, partitioning, and
safe large-table moves. It adds explicit production guardrails and does not replace PostgreSQL's
version-specific documentation or an incident response process.
