# Storage Engines and Indexes

Covers DDIA 2nd ed. Chapter 4 (storage and retrieval: log-structured and B-tree engines, secondary indexes, in-memory stores, column storage, multidimensional, full-text, and vector indexes).

## Operating stance

- You rarely build a storage engine, but you choose and tune one. Know enough internals to predict how a workload and a tuning knob will behave.
- First classify the workload: OLTP (many small keyed reads/writes, low latency) or analytics (large scans, aggregates). Engines for each look very different under the same SQL surface.
- Benchmark with your own data shape and access pattern, long enough to reach steady state. Generic benchmark rankings do not transfer.

## Indexes: the core trade-off

- An index is derived data built from the primary records to speed lookups. Adding or dropping one changes performance, not content.
- Appending to a file is the cheapest possible write. Every index adds write cost and disk space.
- Rule: index for the queries you actually run. Do not index everything; each index taxes every write.
- An append-only log alone gives fast writes and O(n) reads. Every engine below is a way to pay some write cost for faster reads.

## Hash index over an append-only log

- Keep an in-memory hash map from key to file offset of the latest value.
- Limits: the whole key set must fit in RAM; the map must be rebuilt on restart (slow for big data); old values never freed without compaction; no efficient range scans. On-disk hash tables perform poorly (random I/O, costly resizing, collision handling).
- Use only for small key spaces with point lookups. Sorted structures are the default in practice.

## LSM-tree (log-structured) engines

Mechanics:

- Writes go to a sorted in-memory structure (memtable) and to an unsorted write-ahead log for crash recovery.
- When the memtable passes a size threshold (a few MB), flush it as an immutable sorted file (SSTable). The log portion it covered can then be dropped.
- SSTable: sorted keys, one entry per key, grouped into compressed blocks of a few KB, with a sparse index of first-key-per-block.
- Reads check memtable, then segments newest to oldest, stopping at the first hit.
- Background merge (like mergesort) combines segments and keeps only the newest value per key.
- Deletes write a tombstone; the old value disappears only after the tombstone is merged down to the oldest segment.
- Immutable segments make crash recovery simple (discard partial files) and suit object storage. Log records carry checksums to detect torn or partial entries.
- Used by: RocksDB, Cassandra, ScyllaDB, HBase; Lucene uses the same pattern for its term files.

Bloom filters:

- Per-segment bit array answering "definitely absent" or "maybe present". Lets reads skip segments that cannot hold the key, which matters for missing keys and long-unchanged keys.
- Sizing: about 10 bits per key gives roughly 1% false positives; each extra ~5 bits per key cuts that about tenfold.
- False positives cost only a wasted block read. Bloom filters do nothing for range queries.

Compaction strategies:

| Strategy    | How                                                                                                                              | Strengths                                                | Costs                                                                                            | Pick when                                                              |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| Size-tiered | Merge newer, smaller tables into progressively larger ones                                                                       | Highest write throughput; data rewritten few times       | Very large old tables; needs lots of temporary disk during merges; more tables to check per read | Write-heavy, few reads                                                 |
| Leveled     | Fixed-size tables in levels L0, L1, ...; each level key-range partitioned and larger than the one before; spill level i into i+1 | Fewer tables per read; incremental; lower space overhead | More rewrite work                                                                                | Read-heavy; or a small hot key set updated often plus a large cold set |

## B-tree engines

Mechanics:

- Data divided into fixed-size pages (4 KiB traditionally; PostgreSQL 8 KiB, MySQL 16 KiB by default) addressed by page number.
- Root page holds key boundaries and child references; descend to a leaf holding values or value references. Branching factor is typically several hundred, so 3-4 levels cover most databases.
- Update overwrites the leaf page in place. Insert into a full page splits it in two and updates the parent, possibly cascading to a new root. The tree stays balanced, depth O(log n).
- Standard index in nearly all relational databases and many others.

Reliability:

- In-place multi-page writes (splits) can leave an orphaned page or a torn (half-written) page on crash.
- Mitigation: write-ahead log (journal). Every change goes to the WAL first; recovery replays it. Durability requires the WAL fsynced, not just the page buffered.
- Pages are buffered in memory and flushed later; the WAL is what protects them.

Variants worth recognizing:

- Copy-on-write B-trees (e.g. LMDB): write modified pages elsewhere and new parents; no WAL needed; also enables snapshot reads for concurrency control.
- Abbreviated keys in interior pages: more keys per page, higher branching, fewer levels.
- Sibling pointers on leaves and sequential leaf layout: faster ordered scans.

## B-tree vs LSM-tree

| Dimension           | B-tree                                                                                   | LSM-tree                                                                                                               |
| ------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| General tendency    | Faster, more predictable reads                                                           | Higher write throughput                                                                                                |
| Point read          | One page per level; predictable                                                          | May probe several segments; Bloom filters help                                                                         |
| Range read          | Simple ordered walk                                                                      | Merge across all segments; Bloom filters useless                                                                       |
| Write pattern       | Random, scattered page overwrites                                                        | Large sequential segment writes                                                                                        |
| Write amplification | WAL plus full page write even for a few changed bytes                                    | WAL, flush, plus each compaction rewrite; usually lower overall, and blocks compress                                   |
| Disk space          | Fragmentation after deletes; needs vacuum-like process; free pages rarely returned to OS | Compact, compressed; overwritten data lingers until compaction (low with leveled, high with size-tiered during merges) |
| Latency spikes      | Fewer from background work                                                               | If compaction falls behind, memtable fills and engine stalls reads/writes (backpressure)                               |
| Deletion guarantee  | Overwrite in place                                                                       | Deleted data persists in older levels until tombstone fully compacts; matters for erasure compliance                   |
| Snapshots/backups   | Harder with in-place overwrite                                                           | Cheap: flush memtable and pin current immutable segment files                                                          |

Notes:

- Sequential writes beat random writes even on SSDs: flash erases in large blocks, so scattered writes force controller garbage collection, which eats bandwidth and wears the drive. The gap is far larger on spinning disks.
- Lower write amplification also means longer SSD life.
- Write amplification = bytes written to disk / bytes the app logically wrote. In write-bound systems it caps throughput.
- Measure LSM throughput after compaction is running; an empty LSM benchmark is misleadingly fast.
- If values are much larger than keys, key-value separation (compacting keys plus pointers only) cuts LSM write amplification.
- Hybrids exist (multiple B-trees merged LSM-style). NVMe SSDs serve many parallel reads; the engine must be designed to use that.

## Embedded engines

- Library in the app process, no network API (e.g. SQLite, RocksDB, LMDB, DuckDB, KùzuDB).
- Fit: mobile/local data; backend data that fits one machine with modest concurrent transactions; per-tenant databases when tenants are small and never queried together.

## Secondary, clustered, and covering indexes

- Primary key index resolves a unique ID to a record. Secondary index keys are not unique: store a list of matching IDs per key (postings list) or make entries unique by appending the row ID. Both B-trees and LSM engines can implement them.

| Index style                 | Stores                                                                      | Read cost                       | Write/space cost                                                          |
| --------------------------- | --------------------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------- |
| Clustered                   | Full row inside the index (e.g. InnoDB primary key)                         | Lowest for PK lookups           | Secondary indexes must point by PK, adding a second lookup                |
| Heap + reference            | Row in an unordered heap file; index holds location (e.g. PostgreSQL) or PK | Extra hop to heap               | Growing a row may move it: update all indexes or leave forwarding pointer |
| Covering (included columns) | Some columns copied into the index                                          | Query answered from index alone | Duplicate data; slower writes, more disk                                  |

Rule: add included columns only for hot, stable query shapes; each one is another copy to update.

## In-memory databases

- Cache-only stores (e.g. Memcached) accept data loss on restart.
- Durable in-memory stores use an append-only change log, periodic snapshots, replication, or battery-backed RAM. Some (e.g. Redis) persist asynchronously, so recent writes can be lost.
- Speed comes mainly from skipping encoding of in-memory structures into disk formats, not from avoiding disk reads; a disk engine with enough RAM already serves reads from the OS page cache.
- Second benefit: rich data structures (sets, priority queues) that are hard to build on disk indexes.
- Questions to settle: acceptable data loss window on crash, restart/reload time, and whether data plus growth fits in RAM.

## Analytical storage

### Warehouse architecture

- HTAP products increasingly run two separate engines behind one SQL interface. Treat them as two systems for capacity and tuning.
- Cloud warehouses separate compute from object storage: scale each independently; integrate with cloud ingestion.
- Open data-lake stacks split into components; choose each deliberately:

| Layer          | Role                                                                         | Examples named in the book                          |
| -------------- | ---------------------------------------------------------------------------- | --------------------------------------------------- |
| Query engine   | Parse, plan, distribute execution                                            | Trino, Presto, DataFusion; Spark/Flink as executors |
| Storage format | Encode rows to immutable files                                               | Parquet, ORC, Lance, Nimble                         |
| Table format   | Which files form a table; schema; inserts/deletes; time travel; transactions | Iceberg, Delta                                      |
| Data catalog   | Which tables exist; create/rename/drop; governance access                    | Polaris, Unity Catalog, Iceberg catalog             |

### Column-oriented storage

- Store each column's values together, in the same row order across columns. A query reads only the columns it touches; analytical queries usually touch a handful of 100+ columns.
- Real engines chunk tables into row blocks (thousands to millions of rows), often aligned to time ranges, so queries skip irrelevant blocks.
- Applies to nested/document data too (Parquet's Dremel-style shredding).
- Do not confuse with wide-column stores (Bigtable, HBase, Accumulo): those are row-oriented with sparse, variable columns per row.

| Aspect            | Row-oriented                      | Column-oriented                                                                      |
| ----------------- | --------------------------------- | ------------------------------------------------------------------------------------ |
| Best at           | Fetch/update whole records by key | Scan and aggregate few columns over many rows                                        |
| Single-row insert | Cheap                             | Expensive in place; batch it                                                         |
| Compression       | Moderate                          | High (repetition within a column)                                                    |
| Typical use       | OLTP, document stores             | Warehouses, embedded analytics (DuckDB), product analytics, some time-series engines |

Compression:

- Bitmap encoding: one bitmap per distinct value when distinct count is small relative to rows. Sparse bitmaps are run-length encoded; adaptive schemes (roaring bitmaps) choose per chunk.
- IN-lists become bitwise OR; multi-column equality becomes bitwise AND across aligned bitmaps.

Sort order:

- Sort whole rows (never columns independently) by chosen keys. Put the most common range filter first (often date), then a common grouping key.
- First sort key compresses extremely well via run-length encoding; later keys progressively less.

Writes:

- Never insert rows into the middle of compressed sorted columns. Buffer recent writes in a row-oriented in-memory store, then merge into new immutable column files in bulk (LSM-like). Queries combine buffer and files transparently.
- Immutable bulk-written files fit object storage.

### Query execution

| Approach                  | How                                                                           | Note                             |
| ------------------------- | ----------------------------------------------------------------------------- | -------------------------------- |
| Interpreted row-at-a-time | Walk query tree per row                                                       | Too slow for large scans         |
| Query compilation         | Generate and JIT-compile code for the specific query (e.g. via LLVM)          | Tight per-row loops              |
| Vectorized processing     | Fixed operators each process a batch of column values, returning e.g. bitmaps | Combine bitmaps with bitwise ops |

Both fast approaches win by sequential memory access, tight branch-free loops, multithreading and SIMD, and operating directly on compressed data.

### Materialized views and data cubes

- Virtual view: a stored query expanded at read time. Materialized view: stored results that must be updated when inputs change (more write work, faster repeated reads).
- Data cube (OLAP cube): precomputed aggregates over combinations of dimensions; roll-ups along any dimension are instant.
- Cubes cannot answer questions on attributes that are not dimensions. Keep raw data as the primary store; use cubes only to accelerate known hot queries.

## Multidimensional, full-text, and vector indexes

Concatenated index (a, b): serves filters on a, or on a and b; useless for b alone. Order columns by query pattern.

Multidimensional (simultaneous ranges on several columns, e.g. lat/long box, date plus temperature, color space):

- Concatenated indexes cannot serve this. Use spatial indexes (R-trees, Bkd-trees; e.g. PostGIS on PostgreSQL GiST), space-filling curves mapped onto a B-tree, or regular grids (squares, triangles, hexagons).

Full-text search:

- Treat each term as a dimension. Inverted index: term to postings list of document IDs, often stored as sparse bitmaps; multi-term queries become bitmap AND/OR.
- Lucene (under Elasticsearch, Solr) keeps term dictionaries in SSTable-like files merged in the background. PostgreSQL GIN uses postings lists for text and JSON fields.
- N-gram (e.g. trigram) indexes allow arbitrary substring and regex search at the cost of large index size.
- Typo tolerance via edit-distance search over a term automaton (Levenshtein automaton).
- Language-specific tokenization, stemming, and synonyms are separate concerns; plan for them per language.

Vector (semantic) search:

- Embedding models map content (text, images, audio, multimodal) to float vectors, often 1,000+ dimensions; nearby vectors mean similar meaning. Distance: cosine similarity or Euclidean.
- Query flow: embed the query (plus context), then nearest-neighbor lookup in a vector index. Used in retrieval-augmented generation.
- "Vector" here is unrelated to vectorized execution.

| Vector index                    | Accuracy                                               | Speed                       | Tuning                                                      |
| ------------------------------- | ------------------------------------------------------ | --------------------------- | ----------------------------------------------------------- |
| Flat                            | Exact                                                  | Slow; compares every vector | None                                                        |
| IVF (clustered partitions)      | Approximate; near neighbors in other partitions missed | Faster                      | Probes: more partitions checked means better recall, slower |
| HNSW (layered proximity graphs) | Approximate                                            | Fast                        | Graph construction and search breadth parameters            |

- R-trees break down at high dimension; use vector-specific indexes (e.g. Faiss, pgvector support IVF and HNSW).
- Approximate indexes trade recall for latency; measure recall on your data.

## Review checklist

- Is the engine type matched to the workload (OLTP vs analytics; write-heavy vs read-heavy)?
- Was the engine benchmarked on real data shape, at steady state with compaction or vacuum running?
- Does every index serve a real query? What is its write and space cost?
- For LSM: which compaction strategy, and why? Is there disk headroom for compaction? Are Bloom filters sized? What happens when compaction lags?
- For B-tree: is the WAL fsynced? Is vacuum/defragmentation planned after mass deletes?
- Are range scans common on an LSM store, where they are costlier?
- Is hard deletion required (privacy)? How long do tombstoned or vacuumed values survive on disk and in snapshots?
- Do concatenated index column orders match filter patterns? Are covering columns justified?
- For in-memory stores: what is the acceptable loss window, reload time, and RAM growth plan?
- For analytics: columnar format? Sort keys chosen from the dominant filters? Writes batched, not row-by-row?
- Are lake components (storage format, table format, catalog, engine) chosen explicitly with deletes and schema change in mind?
- Are cubes or materialized aggregates used only as accelerators, with raw data retained?
- For geo or multi-range filters: is a true multidimensional index in place?
- For search: tokenization, typo handling, and substring needs covered? For vectors: index type, distance metric, recall target, and probe/graph parameters tested?
