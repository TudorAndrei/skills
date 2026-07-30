# PostgreSQL Extensions by Use Case

Self-hosted assumption: you can `CREATE EXTENSION` for anything and install packages/build from source.
Each entry states **what it's for**, **when it wins** over doing the job by hand or with a separate
service, and the **tradeoff** / cost. Maturity tiers: **core** (ships with Postgres / `contrib`),
**standard** (widely deployed, production-safe), **specialized** (powerful but a real operational or
licensing commitment — recommend with an explicit tradeoff note).

## Table of contents

1. AI / vector search
2. Full-text & fuzzy search
3. Time-series & partitioning
4. Geospatial
5. Queues & scheduling
6. Observability & query tuning
7. Bloat & maintenance
8. Connection pooling
9. Scale-out & sharding
10. Analytics & columnar / lakehouse
11. Security, audit & crypto
12. Foreign data & CDC
13. Approximate & specialized data

---

## 1. AI / vector search

- **pgvector** _(standard)_ — vector column type + IVFFlat and HNSW indexes for similarity search
  (embeddings, semantic search, RAG). **Wins over** running a separate vector DB (Pinecone/Weaviate/
  Qdrant) when your vectors live next to relational data you already filter/join on — one system, ACID,
  no sync pipeline. **Tradeoff**: recall/latency tuning (lists/probes for IVFFlat, m/ef for HNSW);
  very large indexes are memory-hungry; brute-force separate stores can still edge it at extreme scale.
- **pgvectorscale** _(specialized)_ — adds StreamingDiskANN + statistical binary quantization on top of
  pgvector for large vector sets that don't fit comfortably in RAM. **Wins** when pgvector's HNSW gets
  too big/slow for the working set. **Tradeoff**: younger, extra build; only worth it past the point
  where plain pgvector hurts.

Guidance: default to **pgvector**; reach for **pgvectorscale** only when index size is the bottleneck.
Prefer HNSW indexes over IVFFlat for most workloads (better recall/latency, no training step).

## 2. Full-text & fuzzy search

- **Built-in FTS (`tsvector`/`tsquery` + GIN)** _(core)_ — no extension needed; good default for
  language-aware full-text. **Wins** for straightforward document search. **Tradeoff**: no BM25
  relevance ranking, awkward for typo tolerance and faceting.
- **pg_trgm** _(core/contrib)_ — trigram similarity for fuzzy matching, `ILIKE '%…%'` acceleration
  (GIN/GiST), typo-tolerant lookup, autocomplete. **Wins** for "search that survives misspellings" and
  making leading-wildcard `LIKE` indexable. **Tradeoff**: not real relevance ranking; index size.
- **pg_search (ParadeDB)** _(specialized)_ — true BM25 full-text search (Tantivy/Lucene-style) inside
  Postgres: relevance scoring, faceting, fast text search at scale. **Wins over** bolting on
  Elasticsearch/OpenSearch when you'd rather not run and sync a second search cluster. **Tradeoff**:
  heavier extension, newer, licensing/packaging considerations; evaluate before betting a search-heavy
  product on it.

Guidance: built-in FTS or **pg_trgm** for most apps; **pg_search** when search is a core product
surface and the alternative is standing up Elasticsearch.

## 3. Time-series & partitioning

- **Native declarative partitioning** _(core)_ — range/list/hash partitions, no extension. **Wins** for
  keeping big append-mostly tables (events, logs, metrics) prunable and cheap to age out (drop old
  partitions vs. delete). **Tradeoff**: you manage partition creation/retention yourself — pair with
  pg_partman.
- **pg_partman** _(standard)_ — automates creation and retention of time/serial partitions on top of
  native partitioning; optional background worker. **Wins** over hand-written partition DDL and cron.
  **Tradeoff**: one more moving part; still native partitions underneath.
- **TimescaleDB** _(specialized)_ — hypertables (automatic partitioning), continuous aggregates,
  compression, retention policies, time-series functions. **Wins** for heavy time-series/metrics
  workloads: transparent chunking, big compression ratios, fast time-bucketed rollups. **Tradeoff**:
  community edition licensing (not vanilla open source for some features), ties schema to the
  extension; for modest time-series, native partitioning + pg_partman may be enough.

Guidance: native partitioning + **pg_partman** as the general answer; **TimescaleDB** when time-series
_is_ the workload and you want compression + continuous aggregates out of the box.

## 4. Geospatial

- **PostGIS** _(standard, de-facto core for geo)_ — the reference geospatial extension: geometry/
  geography types, spatial indexes (GiST/SP-GiST), thousands of functions, projections. **Wins over**
  everything else for maps, proximity, routing, GIS. **Tradeoff**: large; version/upgrade coordination
  with Postgres; but essentially non-negotiable if you do geo.
- **h3-pg** _(specialized)_ — Uber's H3 hexagonal hierarchical geospatial index as PG functions. **Wins**
  for bucketing points into hex cells for aggregation/heatmaps at scale. **Tradeoff**: complements, not
  replaces, PostGIS.

## 5. Queues & scheduling

- **pgmq** _(standard)_ — a lightweight message queue in Postgres (visibility timeouts, archiving),
  SQS-like. **Wins over** a hand-rolled `SELECT … FOR UPDATE SKIP LOCKED` table or running SQS/RabbitMQ
  when queue volume is moderate and you value transactional enqueue with the rest of your data.
  **Tradeoff**: not a replacement for a high-throughput broker at extreme scale.
- **pg_cron** _(standard)_ — cron-style job scheduling inside the database (run SQL on a schedule).
  **Wins over** an external cron/sidecar for DB maintenance (refresh matviews, partition maintenance,
  cleanup) — the schedule lives with the DB and survives app deploys. **Tradeoff**: jobs run in the DB;
  keep heavy work off the primary or target a replica where appropriate.
- **`SELECT … FOR UPDATE SKIP LOCKED`** _(core pattern, not an extension)_ — worth mentioning: for a
  simple job table this is often all you need before reaching for pgmq.

## 6. Observability & query tuning

- **pg_stat_statements** _(core/contrib)_ — normalized query stats: total/mean time, calls, rows, I/O.
  **The single most important thing to enable** — you cannot prioritize query work without it. Near-zero
  overhead. **Tradeoff**: essentially none; enable it.
- **auto_explain** _(core/contrib)_ — logs `EXPLAIN` (optionally ANALYZE) for slow queries
  automatically. **Wins** for catching plans of occasional slow queries you can't reproduce.
  **Tradeoff**: ANALYZE mode adds overhead; sample it.
- **pg_stat_monitor (Percona)** _(standard)_ — pg_stat_statements plus histograms, bucketed time
  windows, client/host attribution, query plan capture. **Wins** when pg_stat_statements' single
  cumulative bucket isn't enough. **Tradeoff**: more overhead and surface than the core module.
- **hypopg** _(standard)_ — hypothetical indexes: test whether an index _would_ be used by the planner
  without building it. **Wins** for index planning on huge tables where a real build is expensive.
  **Tradeoff**: hypothetical only — still verify with a real `CONCURRENTLY` build.
- **index_advisor / pg_qualstats** _(specialized)_ — suggest indexes from observed predicates. **Wins**
  for surfacing missing-index candidates. **Tradeoff**: suggestions need human judgment; over-indexing
  hurts writes.
- **pgstattuple / pg_buffercache / pg_prewarm** _(core/contrib)_ — measure bloat (`pgstattuple`),
  inspect what's in shared buffers (`pg_buffercache`), warm the cache after restart (`pg_prewarm`).
  **Wins** for diagnosing bloat and cold-cache latency. **Tradeoff**: diagnostic; `pgstattuple` scans
  can be heavy on huge tables.

## 7. Bloat & maintenance

- **pg_repack** _(standard)_ — rebuild tables and indexes to remove bloat **without** the long
  `ACCESS EXCLUSIVE` lock of `VACUUM FULL`. **Wins** for reclaiming space on live, high-availability
  tables. **Tradeoff**: needs extra disk (~2× the table) during rebuild and a brief lock at swap time.
- **pg_squeeze** _(specialized)_ — background bloat removal via logical replication of changes; more
  automated than pg_repack. **Tradeoff**: newer, more moving parts.
- **Aggressive autovacuum tuning** _(core, not an extension)_ — usually the _first_ answer to bloat:
  per-table `autovacuum_vacuum_scale_factor`, `autovacuum_vacuum_cost_limit`. Recommend before repack.

## 8. Connection pooling

- **PgBouncer** _(standard)_ — lightweight external connection pooler; transaction pooling multiplexes
  many app connections onto few server connections. **Wins** whenever connection count is high (serverless,
  many app instances) — Postgres backends are ~expensive per connection. **Tradeoff**: transaction mode
  disallows session-level features (some `SET`, advisory locks, prepared statements need care).
- **pgcat** _(standard)_ — Rust pooler with load balancing, sharding-aware routing, failover. **Wins**
  over PgBouncer when you want read-replica load balancing or sharded routing in the pooler.
  **Tradeoff**: younger than PgBouncer.

Note: these are deployment components, not `CREATE EXTENSION`s, but they're core to "modernizing a
deployment" — high connection counts without a pooler is one of the most common scaling failures.

## 9. Scale-out & sharding

- **Citus** _(specialized)_ — distributes tables (sharding) and parallelizes queries across worker
  nodes; also provides columnar storage. **Wins** when a single node is genuinely out of headroom for a
  multi-tenant or analytics workload. **Tradeoff**: distributed-systems complexity, query/constraint
  limitations, licensing specifics; a big architectural commitment — only when single-node tuning is
  exhausted.

## 10. Analytics & columnar / lakehouse

- **Citus columnar / Hydra** _(specialized)_ — columnar table storage for compression + fast scans on
  analytics tables. **Wins** for reporting/OLAP tables scanned by column. **Tradeoff**: not for OLTP
  (no updates/indexes like heap); mixed workloads need care.
- **pg_duckdb / pg_mooncake / pg_lake** _(specialized)_ — embed DuckDB / columnar-lake engines to query
  Parquet/Iceberg and run vectorized analytics from inside Postgres. **Wins** for analytics over
  data-lake files without a separate query engine. **Tradeoff**: young, fast-moving; evaluate carefully.
- **parquet_fdw / clickhouse_fdw** _(specialized)_ — foreign tables over Parquet files or ClickHouse.
  **Wins** for reaching cold/analytical data without ETL into Postgres.

Guidance: for an OLTP database with a reporting problem, first try BRIN indexes, extended statistics,
and a read replica before adopting columnar. Columnar/lakehouse is for genuine analytics scale.

## 11. Security, audit & crypto

- **pgaudit** _(standard)_ — detailed session/object audit logging for compliance (who ran what).
  **Wins** when you need an audit trail for SOC2/HIPAA/PCI. **Tradeoff**: log volume; tune scope.
- **pgcrypto** _(core/contrib)_ — hashing, HMAC, symmetric/asymmetric encryption in SQL. **Wins** for
  column-level encryption and secure hashing without app-side crypto. **Tradeoff**: key management is
  on you; encrypted columns aren't range-indexable.
- **anon (PostgreSQL Anonymizer)** _(specialized)_ — dynamic masking / anonymization for non-prod
  copies. **Wins** for giving devs realistic-but-masked data.
- **set_user** _(specialized)_ — controlled privilege escalation/logging for admin actions.

## 12. Foreign data & CDC

- **postgres_fdw** _(core/contrib)_ — query remote Postgres as local tables. **Wins** for federation,
  gradual migration, cross-DB joins. **Tradeoff**: pushdown limits; remote latency.
- **wal2json / pgoutput (native logical decoding)** _(core)_ — change data capture from the WAL for
  streaming to Kafka/Debezium/downstream. **Wins over** trigger-based CDC (lower overhead). **Tradeoff**:
  replication slot management (a stuck consumer pins WAL and can fill disk — monitor slot lag).

## 13. Approximate & specialized data

- **postgresql-hll** _(specialized)_ — HyperLogLog for fast approximate distinct counts (uniques,
  cardinality). **Wins** for "count distinct" at scale where exact is too slow. **Tradeoff**: approximate.
- **tdigest / t-digest** _(specialized)_ — approximate percentiles (p95/p99) cheaply. **Wins** for
  latency/metric percentiles over huge sets.
- **bloom** _(core/contrib)_ — bloom-filter index for multi-column equality on wide tables where you
  can't index every combination. **Tradeoff**: probabilistic (false positives rechecked); niche.
- **pg_ivm** _(specialized)_ — incrementally-maintained materialized views (kept fresh on write
  instead of full `REFRESH`). **Wins** for expensive aggregates that must stay near-real-time.
  **Tradeoff**: write-time cost; newer.
- **pg_uuidv7** _(standard, or native in PG18+)_ — time-ordered UUIDv7 keys that don't destroy B-tree
  locality like random UUIDv4. **Wins** for UUID primary keys on high-insert tables (far less index
  bloat/page splits). **Tradeoff**: on PG18+ use the built-in `uuidv7()` instead of the extension.

> Legacy note: `uuid-ossp` still shows up in old setups for `uuid_generate_v4()`. On modern Postgres,
> prefer native `gen_random_uuid()` (no extension) — or UUIDv7 above for insert-heavy keys.

---

## Where to discover more extensions

The catalog above is the high-leverage core, but the ecosystem is large (1000+ extensions). When a
use case here isn't covered, point the user to:

- **PGXN** (pgxn.org) — the PostgreSQL Extension Network, the canonical registry.
- **Community rankings** — e.g. 1bench.dev's ranked/compared extension list, and the annual "extensions
  you should know" roundups (Aiven, Neon, Timescale) for what's gaining production adoption.
- **`contrib`** — always check what ships in your Postgres `contrib` package first; many needs
  (`pg_trgm`, `pg_stat_statements`, `pgcrypto`, `bloom`, `postgres_fdw`, `pgstattuple`) are already
  there, just not `CREATE EXTENSION`-ed yet.

When recommending anything outside this catalog, still apply the maturity/tradeoff discipline: state
the tier, why it fits _this_ workload, and what it costs.
