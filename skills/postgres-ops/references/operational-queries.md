# Operational PostgreSQL Queries and Patterns

These are starting points, not a substitute for understanding the application and PostgreSQL
version. Run the read-only queries first, use a least-privileged role where possible, and adjust
schema/table names. Snapshot/copy query text before sharing it because it can contain sensitive
values.

## Query plans

```sql
-- Read-only: shows the planned path without executing the query.
EXPLAIN (COSTS, VERBOSE, BUFFERS, FORMAT TEXT)
SELECT ...;

-- Read-only statement, but EXPLAIN ANALYZE executes the query.
-- Use a representative, bounded query only after considering production impact.
EXPLAIN (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT TEXT)
SELECT ...;
```

Look for estimates that differ sharply from actual rows; unexpected sequential scans; repeated
loops; sort/hash operations spilling to disk; and buffer reads that dominate time. A sequential
scan may be optimal if most rows qualify.

## Active queries, transactions, and waits

```sql
-- Read-only: sessions with active or long-running transactions.
SELECT pid,
       usename,
       application_name,
       state,
       now() - xact_start AS transaction_age,
       now() - query_start AS query_age,
       wait_event_type,
       wait_event,
       left(query, 500) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start;

-- Read-only: sessions waiting on locks, including likely blockers.
SELECT waiting.pid AS waiting_pid,
       left(waiting.query, 250) AS waiting_query,
       blocker.pid AS blocker_pid,
       left(blocker.query, 250) AS blocker_query,
       now() - blocker.xact_start AS blocker_transaction_age
FROM pg_locks waiting_lock
JOIN pg_stat_activity waiting ON waiting.pid = waiting_lock.pid
JOIN pg_locks blocker_lock
  ON blocker_lock.locktype = waiting_lock.locktype
 AND blocker_lock.database IS NOT DISTINCT FROM waiting_lock.database
 AND blocker_lock.relation IS NOT DISTINCT FROM waiting_lock.relation
 AND blocker_lock.page IS NOT DISTINCT FROM waiting_lock.page
 AND blocker_lock.tuple IS NOT DISTINCT FROM waiting_lock.tuple
 AND blocker_lock.virtualxid IS NOT DISTINCT FROM waiting_lock.virtualxid
 AND blocker_lock.transactionid IS NOT DISTINCT FROM waiting_lock.transactionid
 AND blocker_lock.classid IS NOT DISTINCT FROM waiting_lock.classid
 AND blocker_lock.objid IS NOT DISTINCT FROM waiting_lock.objid
 AND blocker_lock.objsubid IS NOT DISTINCT FROM waiting_lock.objsubid
 AND blocker_lock.pid <> waiting_lock.pid
JOIN pg_stat_activity blocker ON blocker.pid = blocker_lock.pid
WHERE NOT waiting_lock.granted
  AND blocker_lock.granted;
```

Do not terminate a backend until the owner has identified its business operation and accepted the
rollback consequences. Fix the code path that permits long idle or external-call transactions.

## Table maintenance and transaction-ID risk

```sql
-- Read-only: tables where dead tuples or stale maintenance merit investigation.
SELECT schemaname,
       relname,
       n_live_tup,
       n_dead_tup,
       last_autovacuum,
       last_autoanalyze,
       vacuum_count,
       autovacuum_count,
       analyze_count,
       autoanalyze_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 30;

-- Read-only: currently running vacuum/autovacuum workers.
SELECT pid,
       datname,
       usename,
       state,
       now() - query_start AS runtime,
       wait_event_type,
       wait_event,
       left(query, 500) AS query
FROM pg_stat_activity
WHERE query ILIKE '%vacuum%'
ORDER BY query_start;

-- Read-only: database-wide transaction-ID age. Interpret against the version and monitoring policy.
SELECT datname,
       age(datfrozenxid) AS xid_age,
       datfrozenxid
FROM pg_database
ORDER BY age(datfrozenxid) DESC;
```

`n_dead_tup` is an estimate, not a verdict. Combine it with trend data, table size, write rate,
vacuum progress, long transactions, and disk pressure before changing autovacuum settings.

## Index and connection observations

```sql
-- Read-only: index scans and approximate relation/index sizes.
SELECT schemaname,
       relname,
       indexrelname,
       idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;

-- Read-only: connection count by state and client application.
SELECT application_name,
       state,
       count(*) AS connections
FROM pg_stat_activity
GROUP BY application_name, state
ORDER BY connections DESC;
```

An unused-index report needs a long enough representative window and awareness of constraints,
replication, and rare but critical queries. Never drop an index solely because its current scan count
is zero.

## Online index and constraint patterns

```sql
-- Production-changing: cannot run inside BEGIN/COMMIT.
CREATE INDEX CONCURRENTLY IF NOT EXISTS orders_customer_created_at_idx
  ON public.orders (customer_id, created_at DESC);

-- Production-changing: split validation from creation to reduce the initial lock burden.
ALTER TABLE public.orders
  ADD CONSTRAINT orders_status_check
  CHECK (status IN ('pending', 'paid', 'cancelled')) NOT VALID;

-- Production-changing: schedule and observe separately.
ALTER TABLE public.orders
  VALIDATE CONSTRAINT orders_status_check;
```

Set a `lock_timeout` and `statement_timeout` suited to the deployment in the migration session, then
monitor lock waits, replication lag, write latency, and build progress. `CONCURRENTLY` minimizes a
specific kind of blocking; it does not make a heavy index build free.

## Queue claim pattern

```sql
-- Production-changing: claim one eligible job in a short transaction.
WITH next_job AS (
  SELECT id
  FROM public.jobs
  WHERE state = 'ready'
    AND run_at <= now()
  ORDER BY priority DESC, run_at, id
  FOR UPDATE SKIP LOCKED
  LIMIT 1
)
UPDATE public.jobs AS job
SET state = 'running',
    locked_at = now(),
    locked_by = $1
FROM next_job
WHERE job.id = next_job.id
RETURNING job.*;
```

Index the eligibility and ordering path after validating the workload. A production queue also needs
a lease-expiry recovery path, bounded retries, idempotent job execution, and metrics for queue age
and failed claims.

## Bounded, resumable backfill

```sql
-- Production-changing: perform repeatedly from application/job code, with a checkpoint.
-- Keep each transaction small; the exact predicate and batch size are workload-specific.
WITH batch AS (
  SELECT id
  FROM public.source_table
  WHERE id > $1
  ORDER BY id
  LIMIT $2
)
INSERT INTO public.target_table (id, payload)
SELECT s.id, s.payload
FROM public.source_table AS s
JOIN batch USING (id)
ON CONFLICT (id) DO UPDATE
  SET payload = EXCLUDED.payload;
```

Track the last completed key, rows copied, error/retry counts, source/target counts or checksums,
write latency, WAL/replication lag, and the cutover criteria. If source writes continue, use a
carefully tested dual-write or trigger mirror and ensure every mirrored write is idempotent.
