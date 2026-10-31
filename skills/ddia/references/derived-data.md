# Derived Data, Unbundling, and End-to-End Correctness

Covers DDIA 2nd ed., Chapter 13 (A Philosophy of Streaming Systems).

## Systems of record vs derived data

- System of record: the authoritative copy where a fact is first written. If it disagrees with anything else, it wins.
- Derived data: anything recomputable from the system of record (indexes, caches, materialized views, search indexes, warehouse tables, ML models, aggregates, recommendations).
- No single product serves every access pattern well, and even "general-purpose" databases target a usage pattern. Real applications compose several specialised stores. The integration problem grows with the number of representations.

Rules:

- For every dataset, write down: where is it first written, what is it derived from, and by which process. If you cannot answer, the design is not finished.
- Each derived store must have exactly one input path: the change stream of its source. No side door writes from the application.
- Prefer one integrated product while it meets all requirements. Compose multiple stores only when no single tool fits. Operating each extra system has a learning and ops cost, and building for scale you do not need is premature optimisation.

## Total order as the integration primitive

- Funnel all writes for a domain through one component that decides their order (a system-of-record DB with CDC, or an event log). Every derived system then applies the same writes in the same order and converges (state machine replication).
- Whether you use CDC or event sourcing matters less than having one decided order.
- Dual writes from the application to two stores have no common order; concurrent writes can be applied in opposite orders and diverge permanently.
- Log-driven derivation can be made deterministic and idempotent, so recovery is "replay from offset".

### Where total order breaks

| Situation                        | Why no total order                                       | Mitigation                                                         |
| -------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------ |
| Throughput beyond one leader     | Log must be sharded; cross-shard order undefined         | Shard by the entity whose events must be ordered                   |
| Multi-region                     | Separate leader per region to avoid cross-region latency | Accept per-region order; design for concurrent cross-region events |
| Microservices with private state | Events from different services have no shared sequence   | Carry causal references across services                            |
| Offline / client-side state      | Clients and server see events in different orders        | Sync engines, conflict resolution                                  |

Total order broadcast is equivalent to consensus, and most consensus algorithms cannot split ordering work across nodes.

### Capturing causality without total order

When two events live in different stores but one logically depends on the other (e.g., a permission change followed by an action whose visibility depends on it), consumers can process them in the wrong order and leak or misroute data. Options, none complete:

- Logical timestamps: ordering without coordination, but consumers must still handle out-of-order arrival, and extra metadata travels with events.
- Log the state the user saw as an event with an ID; later events reference that ID to record the dependency.
- Conflict resolution handles out-of-order state updates but cannot undo external side effects (sent notifications, emails).

Rule: when a derived action is a join of two independently ordered streams (e.g., notifications = messages joined with ACLs), flag it as a causality risk.

## Derived data vs distributed transactions

| Aspect                | Distributed transactions (2PC/XA)                                    | Log-based derived data                                 |
| --------------------- | -------------------------------------------------------------------- | ------------------------------------------------------ |
| Correctness mechanism | Atomic commit                                                        | Deterministic retry + idempotence                      |
| Read-your-writes      | Usually yes                                                          | Not by default (async)                                 |
| Failure behaviour     | One participant failing aborts all: amplifies faults                 | Faults contained; slow consumer buffers and catches up |
| Heterogeneous systems | Needs a shared protocol; XA has poor fault tolerance and performance | Needs only an ordered log and idempotent consumers     |
| Team coupling         | Tight                                                                | Loose; teams own stages independently                  |

Rule: use transactions inside one system (one DB, one stream processor). Across technology boundaries, use an ordered event log with idempotent writes. Do not settle for "eventual consistency, deal with it": give users a read-your-writes path where they need it (e.g., wait on output stream, route read to source).

## Batch and stream for derived state

- Both are deterministic functions from immutable inputs to append-only outputs; stream adds managed fault-tolerant state.
- Maintain derived data asynchronously. Synchronous maintenance (like an in-transaction secondary index) spreads failures. Cross-shard secondary indexes are also more scalable and reliable when updated asynchronously.
- Stream: low-latency propagation of new changes. Batch: reprocess full history to build new views.

### Reprocessing for evolution

- Without reprocessing, schema evolution is limited to additive changes (new optional field, new record type). With reprocessing you can restructure into a different model.
- Gradual migration: derive the new view alongside the old one from the same source, move a small share of reads to it, grow the share, then delete the old view. Every step is reversible, so you can move faster.

### Unifying batch and stream (kappa-style; lambda is obsolete)

A single engine handles both only if it has:

- Replay of historical input through the same code (log retention or reading from object storage).
- Exactly-once / effectively-once output.
- Event-time windowing (processing time means nothing during replay).

## Unbundling the database

Databases already contain derivation machinery: secondary indexes, materialized views, replication logs, full-text indexes. `CREATE INDEX` is snapshot + sort + catch up on backlog + keep updated, which is the same as bootstrapping a follower or CDC consumer. An organisation's dataflow is one large database whose indexes and triggers are spread across separate systems and teams.

| Approach                                                                              | Unifies                                     | Tradition                                                | Hard part                           |
| ------------------------------------------------------------------------------------- | ------------------------------------------- | -------------------------------------------------------- | ----------------------------------- |
| Federated database / polystore (e.g., foreign data wrappers, federated query engines) | Reads: one query interface over many stores | Relational: high-level language, complex implementation  | Mapping data models (manageable)    |
| Unbundled database (CDC + event logs + stream processors)                             | Writes: changes reliably reach every store  | Unix: small tools, uniform low-level interface (the log) | Keeping writes in sync under faults |

Loose coupling from log-based integration:

- System level: a slow or failed consumer does not affect producers or other consumers; it catches up later without data loss.
- Human level: teams build and run their stages independently behind a log interface.

Unbundling does not replace databases: they still hold operator state and serve outputs. Specialised engines (e.g., warehouse query engines) remain best for their workloads. The goal is breadth across workloads, not beating one database at its own job.

## Designing around dataflow

- Model the system like a spreadsheet: when an input changes, every dependent view updates automatically, but with fault tolerance, scale, and durability.
- Application code is the derivation function. Standard derivations (secondary index) are built into DBs; custom ones (search analysis, feature engineering, UI-shaped caches) need application code.
- Keep application code and state separate. Databases are poor places to deploy code (no proper packaging, versioning, rolling upgrades, observability, external calls). Run code on deployment platforms; keep durable state in stores.
- A database used as a passive shared variable forces polling. Dataflow inverts that: code subscribes to state changes and emits state changes.
- Requirements for derived-data pipelines: stable ordering (all views apply events in the same order) and reliable delivery and processing (one lost message desynchronises a view permanently).

### Stream processors vs request/response services

|                                               | Synchronous service call                 | Dataflow (subscribe ahead of time)                       |
| --------------------------------------------- | ---------------------------------------- | -------------------------------------------------------- |
| Needed data (e.g., reference rates, profiles) | Queried from another service per request | Pushed as change stream into a local store before needed |
| Latency                                       | Network round trip                       | Local lookup                                             |
| Availability                                  | Coupled to the other service             | Survives the other service being down                    |
| Freshness                                     | Current at call time                     | Bounded by stream lag                                    |
| Reprocessing                                  | Must fetch historical value              | Must keep historical versions (time-dependent join)      |

A local cache refreshed by subscription is the dataflow approach. Either way, handle time dependence: reprocessing old events needs the value at that time.

## Write path vs read path

- Write path: eager work done when data arrives (precompute). Read path: lazy work done when someone asks.
- Derived datasets (indexes, caches, materialized views) are where the two meet; they move the boundary.

| Choice                          | Write cost                     | Read cost                    |
| ------------------------------- | ------------------------------ | ---------------------------- |
| No index (scan)                 | None                           | Very high                    |
| Index                           | Moderate                       | Moderate                     |
| Cache of popular query results  | Higher (maintain per new data) | Very low for popular queries |
| Precompute all possible results | Infeasible                     | Minimal                      |

Rule: place the boundary per workload, possibly differently for different keys (e.g., hot vs normal entities).

### Extending the write path to clients

- Treat on-device state as a cache/replica of server state; the screen is a materialized view of client model objects.
- Push changes to clients (server-sent events, WebSockets) instead of polling. Clients reconnect from their last offset, like log consumers.
- Obstacle: most datastores, libraries, and protocols assume request/response, not subscriptions.

### Reads as events

- Routing read requests through the same stream operator as writes makes serving a stream-table join; a subscription is a long-lived join.
- Logging reads records what the user saw before acting, which supports causal tracking and provenance, at storage and I/O cost.
- Multi-shard queries can reuse stream-processor routing and joins (e.g., fraud scoring across differently sharded reputation stores). Prefer a database that already does multi-shard joins unless you are past its limits.

## End-to-end correctness

- Strong DB guarantees (serializable transactions) do not stop application bugs from writing bad data or deleting good data. Immutable, append-only inputs make such bugs recoverable.
- Jepsen-style testing shows products often fall short of their claimed guarantees, and weak isolation or quorum settings are easy to misuse.

### Duplicate suppression and the end-to-end argument

- Exactly-once = same final effect as without faults. Processing twice is corruption (double charge, double count).
- Each layer only deduplicates inside its own scope: TCP within a connection; a DB transaction within a session; stream processors within the framework. A user retrying a timed-out request creates a new request that none of these layers sees as a duplicate.
- Fix: generate a unique request ID at the client (UUID, or a hash of the form fields), carry it through every hop, and enforce uniqueness where the effect is recorded (unique constraint on a requests table, inserted in the same transaction as the effect). DB uniqueness constraints hold even under weak isolation; check-then-insert in application code does not.
- The requests table doubles as an event log; downstream effects can be derived from it, deduplicated by the same ID.
- End-to-end argument: a guarantee can be fully provided only at the endpoints. Lower-layer mechanisms reduce how often problems happen but do not replace end-to-end checks. The same applies to checksums (catch software and disk corruption end to end) and encryption (only end-to-end protects against compromised intermediaries).
- There is no good general abstraction for application-level fault tolerance yet. Hand-written concurrency and partial-failure handling is usually wrong, so prefer patterns that make correctness structural (request IDs, single-message writes, deterministic derivation).

### Idempotence requirements

To rely on idempotence: replay must deliver the same messages in the same order, processing must be deterministic, only one writer per value, and failover needs fencing against zombie nodes. Non-naturally-idempotent operations need extra metadata (applied operation IDs or source offsets).

## Enforcing constraints

- Uniqueness and similar constraints (non-negative balance, stock limits, no double booking) need consensus: something must pick a winner among concurrent conflicting requests.
- Scale by sharding on the constrained value; all conflicting requests land on one shard. Asynchronous multi-leader replication cannot enforce them. Rejecting violations immediately requires synchronous coordination.

### Constraints via partitioned logs

- Append each request to the log shard chosen by the constrained value. A single-threaded processor per shard reads in order, checks a local state store derived from the log, and emits accept or reject to an output stream. The client waits on the output stream.
- Works for any constraint where all potentially conflicting writes are routed to one shard. Scales by adding shards.

### Multi-shard operations without atomic commit

Pattern for an operation touching several shards (e.g., debit one account, credit others):

1. Client assigns a request ID; append one request event to the shard of the entity that must validate (e.g., payer).
2. That shard's processor checks its local derived state, reserves, and emits follow-up events (with the same request ID) to each affected shard, including its own.
3. Each receiving processor applies the event to its local state and ignores request IDs it has already applied.
4. Rejections are emitted as events too, so the client learns the outcome by subscribing.

Requirements: per-entity strict log order, at-least-once delivery, deterministic processors, request-ID dedup everywhere. Atomicity comes from the single initial append: once it is durable, all consequences will eventually happen, maybe with duplicates that get dropped. Exactly-once processing in the framework makes local state rollback on crash easier.

## Timeliness vs integrity

"Consistency" mixes two different requirements.

|                       | Timeliness                                | Integrity                                                                  |
| --------------------- | ----------------------------------------- | -------------------------------------------------------------------------- |
| Meaning               | Readers see up-to-date state              | No loss, no duplicates, no contradictions; derived data matches its source |
| Violation             | Temporary staleness; waiting fixes it     | Permanent corruption; needs detection and repair                           |
| Strong form           | Linearizability; weaker: read-after-write | Atomicity, durability, exactly-once derivation                             |
| Cost                  | Needs synchronous coordination            | Achievable asynchronously                                                  |
| Priority in most apps | Lower (stale is annoying)                 | Higher (corruption can be catastrophic)                                    |

- ACID transactions bundle both; dataflow systems decouple them: no timeliness by default unless a consumer waits on the output, but strong integrity.
- Integrity in dataflow comes from:
  - The whole write as one atomically appended message (fits event sourcing).
  - All other state derived from it by deterministic functions.
  - A client request ID carried end to end for dedup and idempotence.
  - Immutable messages plus reprocessing to recover from bugs.

### Loosely interpreted constraints and compensation

- Many businesses already tolerate and repair constraint violations (overselling stock, overbooking, overdrafts with limits, cross-organisation reconciliation). They need repair processes anyway for physical-world failures.
- If the cost of a compensating action is acceptable, write optimistically and validate afterwards. Still validate before irreversible, expensive-to-undo actions (cash payout, physical shipment, sent communications).
- These applications still need integrity (no lost bookings, balanced debits and credits). They do not need timely constraint enforcement.

### Coordination-avoiding systems

- Integrity without coordination plus loose constraints means most of an application can run without synchronous cross-shard or cross-region coordination: multi-leader, multi-region, each region independent, weak timeliness, strong integrity.
- Use serializable transactions in small scopes where they work well; add synchronous coordination only where an operation cannot be undone.
- Trade-off: more coordination = fewer inconsistencies but more outages; less coordination = the reverse. Neither reaches zero; pick the balance per operation.

## Trust, but verify (auditing)

- System models treat faults as possible or impossible; reality is probabilistic. At scale, rare corruption (memory, disk, network, DB bugs such as broken uniqueness enforcement or isolation anomalies) does occur. Application code has far more bugs than DB code and often skips the DB's integrity features.
- ACID consistency assumes bug-free transactions; misuse (e.g., unsafe weak isolation) voids it.
- Rules:
  - Read data back and verify it. Mature storage systems continually scrub and compare replicas.
  - Regularly test restoring from backups.
  - Run end-to-end integrity checks across whole pipelines; every disk, network, service, and algorithm on the path is checked implicitly.
  - Continuous auditing, like automated tests, lets you change systems faster.
- Design for auditability:
  - Event-sourced inputs record why state changed; mutable-table transaction logs often do not.
  - Hash the event log to detect storage corruption. Recompute derived state (or run a redundant derivation) and compare.
  - Deterministic dataflow enables reproducing past behaviour exactly (time-travel debugging).
- Tools: audit tables (hard to guarantee their integrity); periodically signed logs (tamper evidence, but not proof the right entries went in); Merkle trees for efficient inclusion proofs; transparency-log designs (verifiable append-only logs with one leader per log). Full Byzantine-fault-tolerant blockchains are usually too costly for internal systems.

## Review checklist

- Is every dataset labelled as system of record or derived, with its derivation source and process?
- Does any code write to two stores directly (dual write)? Replace with one ordered log feeding derived stores.
- Is there a single ordering point per domain? Where is order undefined (shards, regions, services, clients), and are cross-domain causal dependencies handled?
- Are distributed transactions used across heterogeneous systems where an idempotent log consumer would work?
- Can derived views be rebuilt by reprocessing, and can a new schema run side by side before cutover?
- Where do users need read-your-writes, and how is it provided on top of async derivation?
- Is a client-generated request ID carried end to end and enforced by a uniqueness constraint at the point of effect?
- Which constraints need immediate enforcement (irreversible actions) and which can be checked after the fact with compensation?
- Are constrained writes routed to one shard per constrained value? Are multi-shard operations built from one atomic append plus deduplicated follow-up events?
- Are processors deterministic and fenced on failover?
- Which operations need timeliness and which need only integrity? Is coordination limited to the former?
- Is there continuous end-to-end auditing (checksums or hashes, recompute-and-compare, backup restore tests)?
- Is the extra infrastructure justified, or would one integrated database meet the requirements?
