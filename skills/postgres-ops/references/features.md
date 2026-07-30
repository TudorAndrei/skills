# Modern PostgreSQL Features for Performance (by version)

Two parts:

1. **Version-independent wins** — features available for many releases that deployments still routinely
   fail to use. Usually the highest-ROI, lowest-risk recommendations.
2. **What each major version added** — so you can (a) recommend enabling features the user's version
   already ships and (b) build the case for a major-version upgrade by naming what it unlocks.

Golden rule: **never recommend a feature the running version doesn't have as if it's usable today.** If
it's compelling and newer, surface it in the report's "version upgrade" note instead.

---

## Part 1 — Version-independent performance wins

These have been around long enough to assume availability on any supported version. They're the meat of
most modernization reports.

### Indexing

- **Covering indexes (`INCLUDE`)** _(PG11+)_ — add non-key payload columns so an index-only scan can
  return them without touching the heap. **Win**: turns hot lookups into index-only scans. **Cost**:
  wider index. Ideal when a frequent query selects a couple of columns filtered by an indexed key.
- **BRIN indexes** — tiny block-range indexes for **naturally ordered / append-mostly** columns
  (timestamps, bigserial ids on time-inserted data). **Win**: index is a fraction of a B-tree's size
  and cheap to maintain on huge tables. **Anti-pattern**: useless on randomly-ordered columns — the
  correlation between physical order and value is what makes BRIN work. Always check `correlation` in
  `pg_stats` before recommending.
- **Partial indexes** — index only the rows a query cares about (`WHERE status = 'active'`). **Win**:
  smaller, faster, cheaper to maintain than a full index. Great for hot subsets of a big table.
- **Expression indexes** — index `lower(email)`, `(data->>'id')`, etc. so functional predicates are
  sargable. **Win**: makes common transformed lookups indexable.
- **`CREATE INDEX CONCURRENTLY` / `REINDEX CONCURRENTLY`** _(REINDEX CONCURRENTLY PG12+)_ — build/rebuild
  without blocking writes. **Always** the rollout method for production index changes — call it out in
  every index recommendation.
- **Prune unused/duplicate indexes** — every index taxes writes and bloats. The audit surfaces
  never-scanned indexes; removing them is a real write-throughput win.

### Table storage & write efficiency

- **LZ4 TOAST compression** _(PG14+)_ — faster (de)compression than the default `pglz` for large
  values (text/JSONB/bytea). **Win**: lower CPU on read/write of big columns; often smaller too. Set
  `default_toast_compression = lz4` and/or per-column. (`zstd` also available for WAL, see below.)
- **`fillfactor` + HOT updates** — lowering `fillfactor` on **update-heavy** tables leaves room for
  Heap-Only-Tuple updates that avoid rewriting every index. **Win**: less index bloat and write
  amplification. **Cost**: slightly lower storage density; don't bother on append-only tables.
- **Extended statistics (`CREATE STATISTICS`)** _(PG10+)_ — teach the planner about **correlated
  columns** (`ndistinct`, `dependencies`, `mcv`). **Win**: fixes bad row estimates that cause wrong
  join orders / nested-loop blowups when predicates are correlated (e.g. city + country). One of the
  most underused planner tools.
- **Generated columns** _(stored, PG12+)_ — materialize a derived value once instead of computing it
  per query, and index it. **Win**: precompute + index derived data.

### Structural

- **Native declarative partitioning** _(mature since PG11–13)_ — range/list/hash partitions with
  partition pruning. **Win**: prunes scans to relevant partitions, makes aging out data a `DROP` (not a
  bloat-generating `DELETE`), and keeps autovacuum tractable per-partition. Pair with `pg_partman`.
  **Cost**: partitioning an existing large table is a data migration, not a flag — say so in the report.
- **Autovacuum tuning** — per-table `autovacuum_vacuum_scale_factor` / `autovacuum_vacuum_cost_limit`
  for large or hot tables so vacuum keeps pace. **Win**: prevents bloat and wraparound risk. Usually the
  _first_ answer to bloat, before `pg_repack`.
- **Connection pooling** (PgBouncer/pgcat) — not a SQL feature, but the most common scaling fix: many
  short-lived or idle connections crush a server that pools would carry easily.

### Query patterns worth flagging in old code

- `SELECT … FOR UPDATE SKIP LOCKED` for safe concurrent job/queue consumption.
- `INSERT … ON CONFLICT` (upsert) instead of read-then-write races.
- Window functions / lateral joins instead of correlated subqueries.

---

## Part 2 — What each major version unlocks

Use this to justify upgrades and to enable features the user already has. Impact tags: **[perf]**
planner/execution/storage speed, **[ops]** operational/maintenance, **[sql]** new capability.

### PostgreSQL 12

- **[perf]** Partitioning performance: much faster pruning and INSERT/COPY into partitioned tables;
  foreign keys can reference partitioned tables.
- **[perf]** B-tree space/efficiency improvements; `REINDEX CONCURRENTLY`.
- **[perf]** CTEs inlined by default (no more optimization fence) — old `WITH` queries get faster for
  free; `MATERIALIZED` keyword to opt back in.
- **[sql]** Generated columns (stored).
- **[ops]** Pluggable table storage API (foundation for later engines).

### PostgreSQL 13

- **[perf]** **B-tree deduplication** — dramatically smaller indexes on columns with many duplicate
  values (a common free win just from upgrading + REINDEX).
- **[perf]** Incremental sort — reuse partial ordering to avoid full sorts.
- **[ops]** Parallel VACUUM (of indexes); `pg_stat_progress_*` for monitoring long operations.
- **[perf]** Partitioned tables: better partition-wise joins/aggregates, logical replication of
  partitioned tables.

### PostgreSQL 14

- **[perf]** **LZ4 TOAST compression** (`default_toast_compression`) — faster large-value I/O.
- **[perf]** Reduced B-tree bloat from frequent updates/deletes; better index cleanup.
- **[perf]** Connection-handling scalability improvements (helps high-connection workloads).
- **[sql]** **JSONB subscripting** (`data['key'] = …`) — cleaner reads/writes.
- **[sql]** Multirange types; `date_bin()` for time bucketing without an extension.
- **[perf]** libpq **pipeline mode** for reduced round-trip latency on batched queries.

### PostgreSQL 15

- **[sql]** **`MERGE`** — conditional INSERT/UPDATE/DELETE in one statement (upsert-plus).
- **[perf]** **WAL compression with LZ4/zstd** (`wal_compression`) — smaller WAL / faster replication &
  backups, cheaper full-page writes.
- **[perf]** Parallel `SELECT DISTINCT`; sort performance improvements.
- **[sql]** `UNIQUE … NULLS NOT DISTINCT` — treat NULLs as equal in unique constraints.
- **[ops]** `pg_stat_statements` tracks planning time; richer stats.
- **[sql]** More SQL/JSON path functions; ICU collations per-database.

### PostgreSQL 16

- **[perf]** **`pg_stat_io`** — per-backend-type / per-context I/O stats; a big observability upgrade for
  diagnosing read vs. write vs. vacuum I/O.
- **[perf]** Parallelized **FULL and RIGHT hash joins**; incremental-sort and window-function speedups.
- **[ops]** **Logical replication from a standby** — offload CDC/replication off the primary.
- **[perf]** CPU acceleration (SIMD) for ASCII/JSON processing; COPY throughput improvements.
- **[ops]** libpq load balancing across multiple hosts; concurrent bulk loading via logical replication.

### PostgreSQL 17

- **[perf]** **Adaptive radix tree for VACUUM** — vastly less memory and faster vacuum of large tables;
  removes the old 1 GB `maintenance_work_mem` ceiling for dead-tuple tracking. Major for big-table ops.
- **[perf]** **Streaming I/O** for sequential scans and `ANALYZE` — better read throughput.
- **[ops]** **Incremental backup** (`pg_basebackup --incremental` + `pg_combinebackup`) — cheaper,
  faster backups of large clusters.
- **[sql]** **`JSON_TABLE`** — turn JSON into relational rows; SQL/JSON constructors/queries.
- **[sql]** `MERGE` gains `RETURNING` and can target updatable views.
- **[perf]** Planner: smarter handling of `IN`/`= ANY` lists, `NOT NULL` proofs, correlated subqueries.
- **[ops]** `EXPLAIN (ANALYZE, SERIALIZE, MEMORY)`; `COPY … ON_ERROR ignore`; `sslnegotiation=direct`
  (faster TLS handshake); `pg_maintain` predefined role; failover-ready logical replication slots.

### PostgreSQL 18

- **[perf]** **Asynchronous I/O** (`io_method` = `worker` or `io_uring` on Linux) — overlaps I/O with
  computation; large gains for read-heavy and scan-heavy workloads. Headline feature of the release.
- **[perf]** **Skip scan** for multicolumn B-tree indexes — an index on `(a, b)` becomes usable even
  when the query only filters on `b`, reducing the need for extra indexes.
- **[perf]** OR-conditions transformed to array lookups; further planner improvements.
- **[ops]** `pg_upgrade` **preserves planner statistics** — no more slow, blind first hours after a
  major upgrade while you re-`ANALYZE`.
- **[sql]** **Native `uuidv7()`** — time-ordered UUIDs without an extension (better index locality than
  v4).
- **[sql]** Virtual generated columns (computed on read) as the default kind; `RETURNING` can expose
  OLD/NEW rows in DML; temporal `WITHOUT OVERLAPS` constraints.
- **[ops]** `EXPLAIN ANALYZE` reports buffers by default; `NOT NULL … NOT VALID` for online constraint
  addition.

> Version note: 18 is the current major as of 2026. Confirm the exact latest minor and the user's
> platform packaging before pinning specifics — point releases add fixes and occasionally clarify
> defaults. When in doubt, verify a feature's introducing version against the official release notes.

---

## How to turn this into recommendations

- The user is **behind on majors** → lead with the upgrade, and cite the 3–5 features from the versions
  they'd cross that matter for _their_ workload (e.g. a bloat-plagued 13 cluster: sell 17's vacuum
  radix tree + 15's WAL compression + 14 LZ4 TOAST).
- The user is **current but on defaults** → the wins are in Part 1: statistics, BRIN/covering/partial
  indexes, LZ4 TOAST, WAL compression, autovacuum tuning, pooling, dropping dead indexes.
- Always pair a feature with the **audit signal** that motivates it (a slow query, a bloated table, a
  cold cache, a bad row estimate) — see `references/audit.md`.
