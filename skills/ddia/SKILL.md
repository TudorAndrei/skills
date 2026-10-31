---
name: ddia
description: Data-system architecture trade-offs from Designing Data-Intensive Applications (2nd ed., Kleppmann & Riccomini). Use when choosing or reviewing a database, data model, storage engine, schema evolution or encoding format, replication, sharding/partitioning, transactions and isolation levels, distributed-system failure handling, consistency or consensus, batch or stream pipelines, CDC, event sourcing, or derived data; when diagnosing race conditions, stale reads, lost updates, or replication lag; or when asked to reason like DDIA.
license: Distilled notes, not book text. The book is (c) Martin Kleppmann and Chris Riccomini, O'Reilly Media.
metadata:
  source: "Designing Data-Intensive Applications, 2nd edition (O'Reilly, 2026)"
---

# Designing Data-Intensive Applications

Operating rules distilled from the book. Its central claim: there are no best data systems, only **trade-offs** that fit a given workload, failure model and team. Name the trade-off, state what you give up, and tie the choice to a measured or stated requirement.

## Steps

1. **Pin the requirements.** Write down the workload (read/write ratio, data volume, growth, access patterns, OLTP or analytics), the latency target as a percentile (p99, not mean), durability and availability needs, and the consistency the business really needs. Done when each later choice can point at one of these lines. Missing numbers are questions for the user, not guesses.
2. **Find the system of record.** Identify which store holds the authoritative copy of each piece of data, and which stores are derived (caches, indexes, warehouses, materialized views). Done when every store is labelled "record" or "derived from X via Y".
3. **Walk the topic table** below. For each row the design touches, open the reference file and apply its rules and review checklist. Done when every touched row has a stated choice and the trade-off it accepts.
4. **Name the failure modes.** For each component, state what happens on node crash, network partition, process pause, clock skew, duplicate or reordered messages, and a partial write. Done when each has a stated outcome (blocked, retried idempotently, lost, inconsistent until repaired) and the user has accepted any loss.
5. **Recommend the simplest design that meets step 1.** A single node, one database, and plain transactions beat a distributed design until a measured requirement forces the move. Report the choice, the trade-off, and the trigger that would force a revisit.

## Topic table

| Design touches                                                                                                     | Reference                                                                    |
| ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| OLTP vs analytics, cloud vs self-hosted, single node vs distributed; latency percentiles, reliability, scalability | [`references/foundations.md`](references/foundations.md)                     |
| Relational vs document vs graph, normalization, query languages, event-sourced models, DataFrames                  | [`references/data-models.md`](references/data-models.md)                     |
| Storage engines: B-tree vs LSM, indexes, column storage, in-memory, vector and full-text search                    | [`references/storage-engines.md`](references/storage-engines.md)             |
| Encoding formats, schema evolution, forward/backward compatibility, RPC, rolling upgrades, workflows               | [`references/encoding-evolution.md`](references/encoding-evolution.md)       |
| Replicas, failover, replication lag, multi-leader, leaderless/quorums, conflict resolution, CRDTs                  | [`references/replication.md`](references/replication.md)                     |
| Sharding/partitioning keys, hot spots, rebalancing, request routing, secondary indexes across shards               | [`references/sharding.md`](references/sharding.md)                           |
| Transactions, isolation levels, race conditions, lost updates, write skew, 2PC, distributed transactions           | [`references/transactions.md`](references/transactions.md)                   |
| Partial failures, timeouts, unreliable networks and clocks, process pauses, leases, fencing tokens                 | [`references/distributed-faults.md`](references/distributed-faults.md)       |
| Linearizability, causality, ID generation, logical clocks, consensus, leader election, coordination services       | [`references/consistency-consensus.md`](references/consistency-consensus.md) |
| Batch jobs, MapReduce/dataflow engines, distributed filesystems and object stores, joins, ETL                      | [`references/batch-processing.md`](references/batch-processing.md)           |
| Message brokers, logs, CDC, event sourcing, stream joins, windows, event time, exactly-once                        | [`references/stream-processing.md`](references/stream-processing.md)         |
| Derived data, unbundling the database, dataflow apps, end-to-end correctness, integrity vs timeliness, auditing    | [`references/derived-data.md`](references/derived-data.md)                   |
| Personal data, privacy, surveillance, bias in data-driven decisions, retention and deletion                        | [`references/ethics.md`](references/ethics.md)                               |

## Core rules

- **Percentiles, not averages.** State latency as p50/p99/p999. Tail latency amplifies when one request fans out to many backends. Measure response time on the client side, including queueing.
- **Describe load with real parameters.** Requests/sec, read/write ratio, fan-out, data size, hot keys. Scalability is a question about a specific load growing in a specific way, never a property of a system.
- **Faults are normal; design for them.** Hardware, software, network and human faults all happen. Prefer designs where a fault degrades service instead of corrupting data. Make operations easy to undo.
- **Evolvability is a requirement.** Assume the schema, the code and the data shape change while old and new versions run side by side. Every encoding needs a compatibility story both ways.
- **Replication lag is user-visible.** With async replicas, decide explicitly which reads need read-your-writes, monotonic reads or consistent prefix, and route them accordingly.
- **Name the anomaly, then pick the isolation.** "Use transactions" is not an answer. State which anomaly (lost update, write skew, phantom) the code is exposed to and which mechanism prevents it. Most databases default to an isolation level weaker than serializable.
- **Trust no clock and no timeout.** Wall clocks jump, processes pause, and a node cannot know it was declared dead. Any lock or lease that guards a write needs a fencing token checked by the storage side.
- **Consensus is expensive; use it through a proven service.** Leader election, uniqueness, and total order all reduce to consensus. Use an existing coordination service or database feature rather than writing your own.
- **Make every write idempotent end to end.** Retries, redelivery and failover produce duplicates. Carry a request ID from the client through to the final write and deduplicate there.
- **Keep one system of record; derive the rest.** Feed caches, search indexes and warehouses from the record through a log (CDC or event stream), not by dual writes from application code, which race and diverge.
- **Integrity over timeliness.** Stale results are usually acceptable for a while; lost or corrupted data is not. Spend the coordination budget on integrity.
- **Data is about people.** Collect only what the purpose needs, define retention, and plan deletion before storing personal data.

## Output shape

When you advise on a design, give for each decision: the choice, the requirement it serves, the trade-off it accepts, and the failure mode it leaves open. Point at the reference rule you applied.
