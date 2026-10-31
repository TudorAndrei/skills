# Stream Processing

Covers DDIA 2nd ed., Chapter 12 (Stream Processing).

## Streams vs batch

- A stream is unbounded input that arrives over time; an event is a small immutable record of something that happened, usually carrying a timestamp. Related events are grouped into a topic.
- Batch splits unbounded data into arbitrary chunks (per day, per hour) and pays latency equal to the chunk size. Streaming processes each event soon after it happens.
- Consequences of "never finishes": no global sort, so no sort-merge joins; output cannot wait for job completion; fault tolerance cannot mean "restart from the beginning".
- Polling a database for new rows gets more expensive the more often you poll. Prefer push notification via a messaging system. Database triggers are too limited to build on.

## Messaging system design questions

Ask these two questions of any messaging option before comparing products:

1. Producer faster than consumer: drop, buffer (where: memory or disk, and what happens when full), or backpressure (block producer)?
2. Node crash or offline: are messages lost? Durability costs disk writes and/or replication.

Loss tolerance is application-specific. Periodic gauges tolerate occasional loss; counters do not (every lost message is a wrong total). Mass silent loss can make metrics wrong without anyone noticing.

### Delivery styles

| Style                  | Examples of category                                                                 | Pros                                                                        | Cons                                                                                          |
| ---------------------- | ------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Direct, no broker      | UDP multicast feeds, brokerless libraries, UDP metrics agents, webhooks / direct RPC | Lowest latency, no extra infra                                              | Assumes both sides are online; producer crash loses retry buffer; app must handle loss        |
| Message broker (queue) | AMQP/JMS-style brokers                                                               | Tolerates clients coming and going; durability centralised; async producers | Extra hop; queue growth hurts throughput; consumer sees message at an undetermined later time |
| Log-based broker       | Kafka, Kinesis-style partitioned logs                                                | Durable, replayable, ordered per shard, cheap fan-out                       | Parallelism capped by shard count; head-of-line blocking                                      |

### Brokers vs databases

- Classic brokers delete on ack (not long-term storage), assume short queues (backlogs degrade throughput), offer topic-pattern subscription instead of indexed queries, and notify on new data where a DB query is a snapshot that goes stale silently. A DB table as a queue works but is hard to tune.

### Multiple consumers

- Load balancing (one consumer per message; for expensive work) vs fan-out (every subscriber gets each message). Consumer groups combine both: balance inside a group, fan-out across groups.

### Acknowledgment, redelivery, poison messages

- Broker redelivers when ack is missing. The ack may have been lost after successful processing, so redelivery implies at-least-once unless processing is idempotent or committed atomically with the ack.
- Load balancing + redelivery reorders messages, even on brokers that otherwise preserve order. If messages are causally dependent, use one queue per consumer or a partitioned log keyed by the ordering entity.
- A malformed message that crashes consumers loops forever; with strict ordering it blocks the stream. Route repeated failures to a dead letter queue, alert on any DLQ entry, and decide per message: drop, fix and re-publish, or fix consumer code.

## Log-based message brokers

- Producer appends to a shard (partition) log; consumer reads sequentially and waits at the tail. Each message gets a monotonic offset within its shard. Total order inside a shard; no order across shards.
- Throughput scales by sharding; fault tolerance by replication.
- Ordering rule: everything that must be ordered relative to each other must share a partition key (e.g., user ID).

### AMQP-style vs log-based

| Aspect                              | AMQP/JMS-style                                  | Log-based                                                                    |
| ----------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------- |
| Consumption                         | Destructive (ack deletes)                       | Read-only; consumer offset advances                                          |
| Unit of load balancing              | Individual message                              | Whole shard per consumer                                                     |
| Max parallelism                     | Number of consumers                             | Number of shards (unless shared-partition consumer groups are used)          |
| Ordering                            | Lost under load balancing + redelivery          | Preserved within shard                                                       |
| Slow message                        | Others proceed                                  | Blocks the rest of its shard                                                 |
| Ack bookkeeping                     | Per message                                     | Periodic offset commit; restart re-processes since last commit               |
| Replay / new consumer reads history | No                                              | Yes, within retention                                                        |
| Backlog behaviour                   | Queue grows in memory/disk, throughput drops    | Bounded on-disk ring buffer; lagging consumer eventually misses old segments |
| Dead consumers                      | Must delete their queues or they accumulate     | Leave only an offset; cost nothing                                           |
| Best fit                            | Expensive, independent tasks; order unimportant | High throughput, cheap per-message work, ordering matters, data integration  |

The line is blurring: log brokers now offer queue-style shared consumption.

### Offsets, retention, replay

- Consumer offset works like a replication log sequence number: broker = leader, consumer = follower. On failover, the new consumer starts at the last committed offset; anything processed after it is processed again.
- Retention: old segments are deleted or archived. Disk buffers typically hold days to weeks; tiered storage moves old segments to object storage, sometimes as table-format files queryable by batch engines.
- Monitor consumer lag against retention and alert well before the lag exceeds retention.
- A lagging or experimental consumer only hurts itself. You can read a production log for testing without affecting other consumers.
- Replay: start a copy of a consumer at an earlier offset, write to a new output, compare. This gives stream processing the batch property of repeatable derivation.

## Databases and streams

- Every database write is an event. A replication log is a stream of writes; state machine replication says same deterministic events in same order produce same state.
- Heterogeneous stacks (OLTP DB, cache, search index, warehouse) each hold their own copy and must be kept in sync.

### Dual writes: do not use

Application writes to DB then to index/cache:

- Race: concurrent writers can apply in different orders in each system, leaving permanent divergence with no error.
- Partial failure: one write succeeds, the other fails; fixing it is the atomic commit problem.
- Root cause: two leaders with no common order. Fix: make one system the leader and the others followers of its log.

### Change data capture (CDC)

- Extract the committed change stream of the system-of-record database and apply it, in order, to derived systems (search, cache, warehouse). Each derived store is just another consumer.
- Implemented by reading the logical replication log (e.g., via connector frameworks such as Debezium or Kafka Connect), or via first-class change-stream APIs that most databases now offer.
- Transport through a log-based broker to preserve order.
- Asynchronous: the source does not wait for consumers. Slow consumers do not hurt the source, but all replication-lag anomalies apply to readers of derived stores.
- Leaderless / quorum databases have no single change stream; consumers must merge per-node logs like a quorum reader.

Bootstrap rules:

- A new derived system needs a full copy, not just recent changes. Take a consistent snapshot tied to a known log position, then apply changes from that position. Some tools do incremental snapshots with watermarking.
- Alternatively keep the change topic log-compacted: only the latest value per key survives (tombstone = delete). Then rebuild any derived store by reading the compacted topic from offset 0, with no new snapshot of the source. Storage depends on current data size, not write history.

### CDC and schemas

- CDC exposes the internal table schema to every consumer, turning it into a public API. Dropping a column can break production consumers.
- Mitigations: data contracts; the outbox pattern (write an explicitly versioned outbox table in the same transaction as the domain change, and expose only the outbox to CDC). Outbox is a dual write made safe because both writes are in one database transaction. Costs: maintaining the mapping, extra write volume.

### CDC vs event sourcing

| Aspect          | CDC                                               | Event sourcing                                                 |
| --------------- | ------------------------------------------------- | -------------------------------------------------------------- |
| Level           | Low-level row changes extracted from a mutable DB | Application-level immutable events describing intent           |
| App awareness   | App may not know CDC exists                       | App built around the event log                                 |
| Adoption cost   | Low; bolt onto existing DB                        | High; changes the application model                            |
| Event content   | Full new row version per key                      | Action description; later events do not replace earlier ones   |
| Log compaction  | Yes, keep last value per key                      | No; need full history (snapshots only speed up reads/recovery) |
| Order guarantee | Matches DB commit order                           | Defined by append order to the event log                       |

## State, streams, and immutability

- Current state is the integral of the event stream; a change stream is the derivative of the state. The log is the full record; the database is a cached view of the log's end.
- Benefits of immutable events:
  - Auditability and recovery: fix mistakes with compensating events, not erasure; buggy writes can be diagnosed and undone.
  - Richer information than current state (e.g., item added then removed still tells you something).
  - Several read-optimised views derived from one log; new views built side by side with old ones, then cut over. Safer than in-place schema migration.
  - Write and read schemas decouple, so normalisation debates fade: denormalise freely in views because the derivation keeps them consistent.
- Concurrency:
  - Downside: views update asynchronously, so read-your-writes fails unless you add a mechanism. Synchronous view update needs distributed transactions; usually impractical.
  - Upside: design each event as a self-contained user action, so a single append replaces a multi-object transaction. If log and state are sharded the same way, a single-threaded consumer per shard needs no locking.

### Limits of immutability

- High-churn datasets (many updates/deletes on small data) make full history too large; compaction and GC performance become operationally critical.
- Legal and privacy deletion (e.g., GDPR erasure, leaked secrets) requires rewriting history, not appending a delete marker.
- Real deletion is hard: copies live in storage engines, SSD remapping, immutable backups.
- Crypto-shredding: encrypt per deletion unit and delete the key. Decide key granularity up front, because you can only shred all data under one key. Per-item keys make the key store as large as the data.
- Treat deletion as "make retrieval much harder", and still do it.

## What to do with a stream

1. Write it into a store (DB, cache, index) for others to query; best when the stream consumer is that store's only writer.
2. Push to humans (alerts, notifications, dashboards).
3. Transform into other streams (operators/jobs), read-only on input and append-only on output, sharded like batch dataflow.

### Use cases

| Use                           | Shape                                                                          | Notes                                                                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Complex event processing      | Standing pattern queries; engine keeps a state machine and emits a match event | Queries are durable, data is transient (reverse of a DB)                                                                                        |
| Stream analytics              | Rates, rolling averages, comparisons over windows                              | Probabilistic structures (Bloom, HyperLogLog, percentile sketches) are an optional memory optimisation; streaming is not inherently approximate |
| Materialized view maintenance | Keep caches, indexes, event-sourced state current                              | Needs a window back to the beginning of time; frameworks built for short windows fit poorly                                                     |
| Search on streams             | Store queries, match each document against them; index queries to scale        | Percolator-style                                                                                                                                |
| Actors / RPC                  | Concurrency mechanism, ephemeral, often cyclic                                 | Not a stream processor; often no delivery guarantee on crash                                                                                    |

### Incremental view maintenance (IVM)

- Periodic full refresh of a materialized view reprocesses unchanged data and stays stale until the next run.
- Hand-written triggers work only for naturally incremental, partitionable aggregates.
- IVM engines compile SQL into incremental operators that touch only changed data, so views can refresh continuously. They buffer recent events in memory and merge with on-disk state at read time.

## Reasoning about time

### Event time vs processing time

|                                      | Event time                                                             | Processing time                                      |
| ------------------------------------ | ---------------------------------------------------------------------- | ---------------------------------------------------- |
| Source                               | Timestamp in the event                                                 | Clock of the processing node                         |
| Deterministic on replay              | Yes                                                                    | No                                                   |
| Simplicity                           | Need straggler handling                                                | Trivial                                              |
| Correct under lag, restart, backfill | Yes                                                                    | No: backlog after a restart shows as a fake spike    |
| Use when                             | Results must reflect when things happened, or reprocessing is expected | Delay is negligible and approximate results are fine |

Delays come from queueing, network faults, broker contention, consumer restarts, and reprocessing. Events from different producers can arrive out of order.

### Stragglers

- You never know for sure that a window is complete. Pick one policy explicitly:
  - Drop late events, count them as a metric, and alert when the count rises.
  - Emit a correction for the window, and retract the earlier result if needed.
- Low-watermark messages ("nothing earlier than t from now on") help, but with many producers each must be tracked separately, and producer churn complicates it.

### Whose clock

- Device clocks are untrusted; server receipt time is trustworthy but less meaningful. For offline-capable clients, record three times: event time (device), send time (device), receive time (server). Estimate the device offset as receive minus send, then correct the event time (assumes negligible network delay and a stable offset).
- Batch has the same time problems; streaming just makes them visible.

### Window types

| Window   | Definition                                                    | Overlap                        | State                             | Typical use                         |
| -------- | ------------------------------------------------------------- | ------------------------------ | --------------------------------- | ----------------------------------- |
| Tumbling | Fixed length, fixed boundaries                                | None, each event in one window | Small (e.g., counter)             | Per-minute counts                   |
| Hopping  | Fixed length, advances by a smaller hop                       | Yes                            | Compose from tumbling sub-windows | Smoothed rolling metrics            |
| Sliding  | All events within interval of each other, no fixed boundaries | Continuous                     | Buffer of events sorted by time   | Exact "within N minutes" conditions |
| Session  | Per key, closes after an inactivity gap                       | No fixed duration              | Per-session buffer                | Web analytics sessionisation        |

Large windows, sliding windows, and joins buffer events. Size memory/disk for that state.

## Stream joins

| Join                           | Inputs                      | State kept                                                                | Example                                         | Notes                                                                                                                              |
| ------------------------------ | --------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Stream-stream (window join)    | Two event streams           | Recent events from both sides, indexed by join key, for the window length | Search events joined to click events by session | Either side may arrive first; emit non-match when the window expires; embedding one in the other is not a join (loses non-matches) |
| Stream-table (enrichment)      | Event stream + DB changelog | Local copy of table, updated via CDC                                      | Activity events enriched with user profile      | Avoid per-event remote lookups (slow, overloads DB); table side has an infinite window with newest version winning                 |
| Table-table (view maintenance) | Two changelogs              | Current state of both tables                                              | Timeline cache from posts and follows           | Change to the join = change in A joined with current B, plus current A joined with change in B                                     |

### Time dependence of joins

- All three joins query state built from one input while processing the other. The order of state updates relative to events decides the result.
- No ordering across shards or streams means the join is nondeterministic: a rerun can produce different output.
- Fixes: version the dimension (slowly changing dimension; fact event references the version ID; deterministic but blocks log compaction), or denormalise the applicable value (e.g., tax rate at sale time) into the event.

## Fault tolerance and exactly-once

Exactly-once here means effectively-once: retries happen, but the visible effect equals a single processing.

| Mechanism              | How                                                                                                                               | Scope of guarantee                    | Costs / limits                                                                                                            |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Microbatching          | Cut stream into ~1s batches, treat each as a batch job                                                                            | Inside the framework                  | Latency of batch size; implicit processing-time tumbling window; larger windows must carry state across batches           |
| Checkpointing          | Barriers in the stream trigger periodic durable snapshots of operator state; on crash restore and discard output since checkpoint | Inside the framework                  | Does not undo external side effects (DB writes, emails, external topics)                                                  |
| Internal atomic commit | Commit outputs, state changes, and input offsets in one transaction managed by the framework/broker                               | Within one framework/broker ecosystem | Not across heterogeneous systems; amortise by batching many messages per transaction                                      |
| Idempotent writes      | Make each effect safe to repeat, e.g., store the source offset with the written value and skip if already applied                 | External systems too                  | Requires replay in same order, deterministic processing, a single writer per key, and fencing of zombie nodes on failover |

Rule: everything an event causes (downstream messages, external writes, state changes, offset advance) must persist if and only if processing succeeds. If any effect leaves the framework, you need idempotence or a shared atomic commit.

### Rebuilding state after failure

| Option                                             | Trade-off                                                      |
| -------------------------------------------------- | -------------------------------------------------------------- |
| Remote replicated state store                      | Simple recovery; per-message remote calls are slow             |
| Local state + periodic snapshot to durable storage | Fast access; recovery restores snapshot and replays            |
| Local state + changelog to a compacted topic       | Like CDC for operator state; restore by replaying topic        |
| Redundant processing on several nodes              | No restore delay; multiplies compute                           |
| Rebuild from input                                 | Fine for short windows or CDC-fed tables with compacted source |

Choice depends on relative network vs disk latency and bandwidth in your environment.

## Review checklist

- For each channel: what happens when consumers fall behind, and what is lost on a crash? Is that acceptable for this data (gauge vs counter)?
- Queue-style or log-based broker? Does the choice match per-message cost, ordering needs, and replay needs?
- What is the partition key, and does it cover every set of events that must stay ordered? Is shard count enough for target parallelism?
- Is there a dead letter queue with alerting for poison messages?
- Is consumer lag monitored against retention?
- Are any derived stores kept in sync by dual writes? Replace with CDC, an outbox, or event sourcing.
- How does a new derived store bootstrap: snapshot at a known offset, or compacted topic?
- Is the CDC schema treated as a public contract (data contract or outbox)?
- Is deletion (legal erasure) possible given the immutable log and backups? Is crypto-shredding granularity decided?
- Are windows defined on event time? What is the straggler policy, and are late drops counted?
- Which clock stamps events, and is device clock skew corrected?
- Are joins deterministic on replay? Are dimension versions referenced or values denormalised?
- Is enrichment done against a local CDC-fed table rather than per-event remote lookups?
- Which exactly-once mechanism applies, and does it cover every external side effect? Are writes idempotent with fencing on failover?
- How is operator state recovered, and how long does recovery take?
- Does read-your-writes matter for users reading asynchronous views?
