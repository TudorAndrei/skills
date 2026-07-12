# Deployment Audit Queries

Read-only SQL to inventory a running PostgreSQL deployment. Hand these to the user during **intake**
and ask them to paste back the results — the recommendations in the report should be grounded in this
data, not guesses. Everything here is safe to run in production, with one caveat: `pgstattuple` and
bloat estimates on very large tables can be I/O-heavy — note that where flagged.

Group the output into the picture you need: **what version/config**, **what's installed**, **where the
pain is** (slow queries, bloat, missing/unused indexes, cache misses, vacuum health), and **what the
data shape suggests** (partitioning/BRIN candidates).

---

## 1. Version & key configuration

```sql
SELECT version();
SHOW server_version;

-- Settings that shape most recommendations
SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
  'shared_buffers','effective_cache_size','work_mem','maintenance_work_mem',
  'max_connections','max_worker_processes','max_parallel_workers',
  'max_parallel_workers_per_gather','random_page_cost','effective_io_concurrency',
  'default_toast_compression','wal_compression','autovacuum','jit',
  'shared_preload_libraries'
)
ORDER BY name;
```

What to look for: an old `server_version`; `default_toast_compression = pglz` (→ LZ4 opportunity);
`wal_compression = off`; `random_page_cost = 4` on SSD/NVMe (usually should be ~1.1); whether
`pg_stat_statements` is in `shared_preload_libraries`.

## 2. Installed & available extensions

```sql
-- Already installed
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- Available to install (in contrib / installed packages) but not yet enabled
SELECT name, default_version, installed_version, comment
FROM pg_available_extensions
WHERE installed_version IS NULL
ORDER BY name;
```

What to look for: is `pg_stat_statements` installed? Bespoke needs that map to an uninstalled
extension already sitting available (e.g. `pg_trgm`, `pgcrypto`, `bloom`).

## 3. Database & table sizes (where the mass is)

```sql
-- Biggest tables (heap + indexes + TOAST)
SELECT
  n.nspname AS schema,
  c.relname AS table,
  pg_size_pretty(pg_total_relation_size(c.oid))    AS total_size,
  pg_size_pretty(pg_relation_size(c.oid))          AS heap_size,
  pg_size_pretty(pg_indexes_size(c.oid))           AS indexes_size,
  c.reltuples::bigint                              AS approx_rows
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog','information_schema')
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 25;
```

What to look for: the few tables that dominate — those are where partitioning, BRIN, compression, and
bloat removal pay off. Index size ≫ heap size is a smell (over-indexing / bloat).

## 4. Top queries — needs `pg_stat_statements`

```sql
-- By total time (the queries worth optimizing first)
SELECT
  round(total_exec_time::numeric, 1)  AS total_ms,
  calls,
  round(mean_exec_time::numeric, 2)   AS mean_ms,
  rows,
  round(100.0 * shared_blks_hit
        / nullif(shared_blks_hit + shared_blks_read, 0), 1) AS cache_hit_pct,
  query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

If `pg_stat_statements` isn't installed, that's recommendation #1 — you're flying blind without it.
(Column names differ slightly by version: pre-13 uses `total_time`/`mean_time`.)

## 5. Missing indexes — tables taking sequential scans

```sql
SELECT
  schemaname, relname,
  seq_scan, seq_tup_read,
  idx_scan,
  seq_tup_read / nullif(seq_scan, 0) AS avg_rows_per_seq_scan
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 20;
```

High `seq_scan` + high `seq_tup_read` on a large table with few `idx_scan` = index candidate. Confirm
with `EXPLAIN (ANALYZE, BUFFERS)` on the actual query, and consider `hypopg` to test the index
hypothetically before building.

## 6. Unused & duplicate indexes (write tax to shed)

```sql
-- Never (or barely) scanned indexes, largest first
SELECT
  s.schemaname, s.relname AS table, s.indexrelname AS index,
  s.idx_scan,
  pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0
  AND NOT i.indisprimary
  AND NOT i.indisunique
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 20;
```

Zero-scan non-constraint indexes are pure write overhead and bloat — candidates to drop (verify the
stats window is long enough to be representative).

## 7. Cache hit ratio (memory pressure)

```sql
SELECT
  round(100.0 * sum(heap_blks_hit)
        / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0), 2) AS heap_cache_hit_pct,
  round(100.0 * sum(idx_blks_hit)
        / nullif(sum(idx_blks_hit) + sum(idx_blks_read), 0), 2)  AS index_cache_hit_pct
FROM pg_statio_user_tables;
```

Well-tuned OLTP is typically >99% heap cache hit. Much lower → `shared_buffers`/RAM pressure, or a
working set too big for memory (a case for partitioning, BRIN, or on PG16+ inspecting `pg_stat_io`).

## 8. Bloat & vacuum health

```sql
-- Dead tuples and last (auto)vacuum/analyze per table
SELECT
  schemaname, relname,
  n_live_tup, n_dead_tup,
  round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
  last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 20;
```

High `dead_pct` or a stale `last_autovacuum` on a hot table = autovacuum tuning (first) and/or
`pg_repack` (for existing bloat). For a precise bloat measurement on a specific suspect table (heavier
scan — run deliberately):

```sql
CREATE EXTENSION IF NOT EXISTS pgstattuple;   -- if permitted
SELECT * FROM pgstattuple('schema.suspect_table');   -- free_percent, dead_tuple_percent
```

## 9. Long-running transactions & replication slot lag (WAL risk)

```sql
-- Long transactions pin dead tuples and block vacuum cleanup
SELECT pid, state, now() - xact_start AS xact_age, wait_event_type, wait_event,
       left(query, 120) AS query
FROM pg_stat_activity
WHERE state <> 'idle' AND xact_start IS NOT NULL
ORDER BY xact_start
LIMIT 20;

-- Replication slots: a stuck/inactive slot pins WAL and can fill the disk
SELECT slot_name, slot_type, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

## 10. Partitioning & BRIN candidates (data shape)

```sql
-- Column ordering correlation: near ±1 = great BRIN candidate; near 0 = don't bother
SELECT schemaname, tablename, attname, correlation
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog','information_schema')
  AND abs(correlation) > 0.8
  AND n_distinct <> 0
ORDER BY abs(correlation) DESC
LIMIT 30;
```

Big tables (from §3) with a strongly-correlated timestamp/serial column are prime candidates for
**BRIN** indexes and/or **native partitioning** (+ `pg_partman`). Un-partitioned tables that only ever
grow (events/logs/metrics) are partitioning candidates regardless.

---

## Turning audit output into the report

Each recommendation in the report should trace to a signal here:

| Audit signal                                                | Points toward                                        |
| ----------------------------------------------------------- | ---------------------------------------------------- |
| `pg_stat_statements` not installed                          | Enable it (recommendation #1)                        |
| Old `server_version`                                        | Major-version upgrade (cite unlocked features)       |
| `default_toast_compression = pglz`, `wal_compression = off` | LZ4 TOAST + WAL compression                          |
| High `seq_scan`/`seq_tup_read` on big table                 | Missing index (test with `hypopg`)                   |
| Zero-scan non-constraint indexes                            | Drop unused indexes                                  |
| High `dead_pct` / stale autovacuum                          | Autovacuum tuning, then `pg_repack`                  |
| Low cache hit ratio                                         | Memory tuning, partitioning/BRIN, `pg_stat_io` (16+) |
| Correlated timestamp on large table                         | BRIN + native partitioning + `pg_partman`            |
| Bolted-on use case (vector/search/queue/geo/time-series)    | The matching extension in `extensions.md`            |
| Inactive replication slot retaining WAL                     | Operational fix before it fills disk                 |
