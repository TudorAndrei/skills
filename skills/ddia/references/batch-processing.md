# Batch Processing

Covers DDIA 2nd ed., Chapter 11 (Batch Processing).

## Core model: immutable input, regenerated output

- A batch job reads a bounded, read-only input and writes an output that is rebuilt from scratch on every run. It does not mutate records in place the way an OLTP transaction does. The output is derived data.
- Primary metric is throughput (data processed per unit time), not response time. Runtimes of minutes to days are normal; jobs are usually scheduled (hourly, daily) or triggered by upstream completion.
- Why this shape is valuable:
  - Human fault tolerance: a bug that wrote bad output is fixed by reverting code and rerunning, or by pointing readers back at the previous output version. In a mutable OLTP store, reverting code does not repair data already written.
  - Cheap rollback lowers the cost of mistakes, which speeds iteration.
  - The same input files can feed many jobs, including validation jobs that diff today's output against yesterday's.
  - Bulk frameworks use hardware far more efficiently than pushing the same work through an OLTP database and app servers.
- Costs: downstream consumers usually see nothing until the whole job finishes, and any input change (even one byte) forces reprocessing the whole input unless you build incremental logic.

Rules:

- Keep batch jobs free of side effects on external systems. Write only to the job's own output location.
- Version outputs (separate directory or table snapshot / time travel) so you can switch back without recomputing.
- If freshness requirements are below the job's runtime plus schedule interval, batch is the wrong tool; look at stream processing.

## Single-machine baseline (sort vs in-memory aggregation)

Before reaching for a cluster, check whether one machine is enough. Unix-style pipelines (awk, sort, uniq, etc.) handle gigabytes in seconds.

| Approach                              | Working set             | Behaviour when data exceeds RAM                            | Use when                                                |
| ------------------------------------- | ----------------------- | ---------------------------------------------------------- | ------------------------------------------------------- |
| In-memory hash aggregation            | Number of distinct keys | Fails / swaps                                              | Distinct keys fit in memory comfortably                 |
| External sort then scan adjacent keys | Small (bounded buffers) | Spills sorted runs to disk and merges them; sequential I/O | Distinct keys too many for RAM; data fits on local disk |
| Distributed framework                 | Sharded across nodes    | Shuffle across machines                                    | Data or compute exceeds one machine                     |

- Working set = memory needing random access. It depends on distinct keys, not on total records.
- Mergesort-style processing (sorted segments merged) is the same principle as log-structured storage; it is disk-friendly.
- Move to a distributed system only when a single machine's disk or throughput is the real limit.

## Distributed batch = distributed OS

A batch framework has the same three parts as an OS: storage (filesystem), scheduling (orchestrator), and programs connected by data channels. Review each layer separately.

### Storage layer: DFS vs object store

| Property         | Distributed filesystem (e.g., HDFS)                                               | Object store (e.g., S3-style)                                          |
| ---------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Unit             | Large blocks (tens to hundreds of MB) across data nodes; central metadata service | Immutable objects addressed by bucket + key                            |
| Update           | Files, sometimes appends; POSIX-ish semantics in some                             | Whole-object rewrite (put); appends rare                               |
| Directories      | Real directories                                                                  | Key prefixes only; prefix list is recursive; no empty dirs             |
| Rename           | Often atomic                                                                      | Copy + delete per object; not atomic; dir rename = rename every object |
| Links / locks    | Often supported                                                                   | Usually not                                                            |
| Compute locality | Can run task on node holding a replica                                            | Storage and compute separate; scale independently; more network use    |
| Fault tolerance  | Replication or erasure coding on commodity hardware                               | Managed by provider                                                    |

Rules:

- Do not design commit protocols that rely on atomic rename when the target is an object store. Use a table format / manifest commit or write-then-publish-pointer instead.
- Do not assume a system exposing an S3-compatible or POSIX API has the same consistency or performance as the original. Verify the guarantees.
- Object and DFS storage favour large objects and large sequential reads. Small-object, low-latency workloads belong in a key-value store unless the object store tier is explicitly built for it.
- Shared-nothing DFS on commodity hardware expects failures; replication or erasure coding is mandatory, and replicas also give the scheduler more placement options.

### Orchestration layer

Components found in almost every orchestrator (e.g., Kubernetes, YARN):

- Task executor on every node: starts tasks, heartbeats, enforces isolation (cgroups) for security and noisy-neighbour control.
- Resource manager: global view of node capacity and task state; stored in a coordination service. Centralisation is a scalability and availability bottleneck.
- Scheduler: maps task requests (count, CPU, memory, GPU, image, credentials, input/output) onto nodes. App-specific sub-schedulers (operators) can add domain logic.

Resource allocation trade-offs (optimal scheduling is NP-hard; everyone uses heuristics such as FIFO, dominant resource fairness, priority queues, quotas, bin packing):

| Policy                                     | Gain                                             | Risk                                                        |
| ------------------------------------------ | ------------------------------------------------ | ----------------------------------------------------------- |
| Share cores across jobs                    | Utilization, fairness                            | Each job finishes later                                     |
| Gang scheduling (all tasks start together) | Needed for jobs that require all workers at once | Idle reserved cores, deadlock between reservers, starvation |
| Preemption                                 | High-priority jobs start fast                    | Killed work is redone; lower efficiency                     |
| Hold back capacity for future jobs         | Responsiveness for late arrivals                 | Idle capacity if nothing arrives                            |

### Workflows (DAG of jobs)

- A batch workflow is a DAG of jobs, each reading inputs and writing outputs. This differs from durable-execution workflows, which sequence RPCs over small payloads.
- Reasons to split into multiple jobs: several teams consume one output; switching tools between stages; different stages need different sharding keys.
- Two ways to connect stages:
  - Pipe-style direct transfer between tasks (in memory / over network, with backpressure). Faster; stages coupled in time.
  - Materialize to DFS / object store. Decouples timing and ownership; costs I/O. More common between jobs.
- Per-job schedulers do not manage cross-job dependencies; use a workflow scheduler (e.g., Airflow, Dagster, Prefect). A consumer job runs only after all its producers succeed.

## Fault handling

- Long jobs with many tasks will see task failures. Preemption (spot / low-priority capacity) kills tasks more often than hardware faults. Batch is a good fit for cheap preemptible capacity precisely because it tolerates retries.
- Retry at task granularity, not job granularity. This requires tasks to be independent and deterministic given their input.
- Discard partial output of a failed task attempt; only a completed attempt's output is visible.

| Intermediate-data strategy                               | Example   | Recovery                               | Cost                                                          |
| -------------------------------------------------------- | --------- | -------------------------------------- | ------------------------------------------------------------- |
| Write every intermediate result to replicated DFS        | MapReduce | Re-read from DFS                       | Heavy write I/O                                               |
| Keep intermediates in memory / local disk, track lineage | Spark     | Recompute lost partitions from lineage | Recompute can cascade if lineage is long or non-deterministic |
| Periodic checkpoint of operator state                    | Flink     | Restore from checkpoint, replay        | Checkpoint overhead                                           |

Rule: lineage-based recompute is only safe if operators are deterministic. Random numbers, wall-clock reads, unordered iteration, or external lookups break it. Make these deterministic (seeded, input-derived) or checkpoint.

## Processing models

### MapReduce

- Steps: parse input into records, map (record -> zero or more key/value pairs, stateless), framework sorts/groups by key, reduce (key + iterator of values -> output).
- Derived from functional map/fold; statelessness lets the framework parallelise and retry freely.
- Weaknesses: every join or algorithm must be hand-built; sort always happens between stages; intermediate output written to DFS blocks pipelining; new process per task. Treat as historical; modern engines supersede it.

### Dataflow engines (e.g., Spark, Flink)

Treat the whole workflow as one job graph of flexible operators (map, filter, join, group, aggregate). Advantages over MapReduce:

- Sort only where an operator requires it.
- Fuse consecutive operators that keep the same sharding into one task.
- Scheduler sees the full graph and can place consumers next to producers.
- Intermediate state in memory or local disk, not replicated storage.
- Operators start as soon as input is ready.
- Reuse of worker processes.

### Shuffle

- Shuffle = distributed sort where both input and output are sharded. It is deterministic, not random.
- Mechanics: each map task partitions output by hash of key into one sorted local file per reducer; each reducer fetches its files from all mappers and merge-sorts them; reducer is called once per key; reducer outputs become the output shards.
- Number of map tasks follows input shards; number of reduce tasks is chosen by the author. Choosing too few creates large slow reducers; hot keys create skewed reducers.
- Modern warehouses keep shuffle data in memory or in an external replicated shuffle service for speed and resilience.

### Joins and grouping in batch

- Sort-merge (reduce-side) join: both inputs keyed by join key, shuffled to the same reducer; secondary sort orders so the dimension record arrives before the fact records. Reducer holds one dimension record at a time and makes no network calls.
- Group-by / aggregation: shuffle by the grouping key, then iterate.
- Rule: never do per-record remote lookups to a live database from inside a batch job to enrich data. Bring a snapshot of that database into the batch system and join locally. Remote lookups are slow, overload the database, and make output non-deterministic.
- Cost-based optimizers in SQL engines pick join algorithms and join order automatically; prefer declarative interfaces so the engine can do this.

### Query languages, DataFrames, warehouses

| Interface                                           | Strength                                              | Watch out for                                                                          |
| --------------------------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------- |
| SQL on batch engines (e.g., Hive, Trino, Spark SQL) | Optimizer, analyst-friendly, interactive exploration  | Poor fit for iterative graph algorithms, complex ML, multimodal data                   |
| DataFrame APIs (distributed)                        | Familiar to data scientists; lazy plans get optimized | Distributed DataFrames usually lack the index/order of local ones; migration surprises |
| Low-level dataflow / UDF APIs                       | Arbitrary code and formats                            | No optimizer help; easier to write slow jobs                                           |
| Cloud data warehouse                                | Managed, fast columnar SQL                            | Row-by-row work inefficient on columnar storage; often costlier for very large jobs    |

Batch frameworks and cloud warehouses have converged (both use columnar formats, shuffles, SQL, DataFrames). Choose on cost, convenience, team skills, and workload shape, not on category labels.

## Use cases

- ETL/ELT into warehouses: mostly embarrassingly parallel transforms; schedulers retry transient failures and flag repeatedly failing jobs; bad input is easy to inspect and the job rerun. Ownership increasingly distributed across teams (data mesh, data contracts).
- Analytics on a lakehouse: SQL engine over object storage with an open table format and catalog. Two styles: scheduled pre-aggregation (cubes, marts, feeds into real-time OLAP stores) and ad hoc interactive queries where latency matters to analysts.
- ML: feature engineering, training (input = training data, output = weights), batch inference, evaluation, LLM corpus preparation (text extraction, quality filtering, dedup, tokenization, embeddings).
- Graph algorithms: iterate edge-by-edge until convergence using the bulk synchronous parallel (Pregel) model rather than repeated generic jobs.
- Low data-freshness needs with large volume = batch. Low latency needs = not batch.

## Serving derived data from batch output

Problem: batch output (recommendations, reports, features) must reach a database that serves live traffic.

Do not write record-by-record from batch tasks into the production database:

- Per-record network calls are orders of magnitude slower than batch throughput.
- Many parallel tasks can overload the serving database and hurt live queries.
- Breaks all-or-nothing output: partial results become visible, and retried tasks duplicate writes.

| Option                                                                      | How                                                                    | Pros                                                                                                     | Cons                                                                                             |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Push through a log/stream (e.g., Kafka topic) consumed by the serving store | Batch writes to topic; store ingests at its own pace                   | Sequential writes; buffer and throttle; many consumers; network/security boundary between batch and prod | No built-in atomicity: needs an end-of-job marker, and consumers must hide data until it arrives |
| Build new database files in the batch job and bulk-load / swap              | Generate store-native files (e.g., SST files), import, flip atomically | Very fast; atomic version switch; easy rollback to previous version                                      | Hard to apply incremental updates                                                                |
| Hybrid                                                                      | Full swaps for bootstrap plus row-level incremental updates            | Both needs met                                                                                           | More moving parts                                                                                |

## Review checklist

- Is the job's input immutable and its output written to a fresh, versioned location? Can we roll back by repointing readers?
- Does any task write to an external system, call a live service per record, or depend on wall-clock or randomness? If yes, how are retries and partial output handled?
- Would a single machine with an external sort suffice? Is the cluster justified?
- Does the commit protocol assume atomic rename or directories on an object store?
- How are intermediates recovered after task loss: replicated storage, lineage recompute, or checkpoint? Are operators deterministic enough for that choice?
- Are there hot keys or a badly chosen reducer count that will skew the shuffle?
- Are enrichment joins done against a local snapshot rather than a live database?
- Is cross-job ordering handled by a workflow scheduler, with consumers waiting on all producers?
- How does output reach the serving store, and is it all-or-nothing from the reader's view?
- Does the freshness requirement actually tolerate the job interval plus runtime?
- Is preemptible capacity used, and are tasks safe to kill and rerun?
