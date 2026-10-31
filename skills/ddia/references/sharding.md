# Sharding

Covers DDIA 2nd ed., Chapter 7 (Sharding).

## Terms

- **Shard** = a subset of the data, held by a node. Other names for the same thing: partition, range, region, tablet, vnode, vBucket. Do not confuse with the data warehouse "partition" (often a time-based grouping inside a table).
- **Partition key**: the value that decides the shard. Equal keys always land on one shard.
- Sharding is usually combined with replication: each shard has its own replicas (and its own leader in a single-leader setup). A node holds many shards, leading some and following others.

## When to shard

Shard only if data volume or **write** throughput exceeds one node.

- Read throughput alone: use read replicas first.
- A single modern machine is large. Sharding is heavyweight; prefer one shard while it fits.

Costs that sharding adds:

| Cost                 | Detail                                                                                         |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| Partition key choice | Lookups without the key are scatter/gather over all shards; the scheme is hard to change later |
| Cross-shard queries  | Secondary indexes and joins span shards                                                        |
| Cross-shard writes   | Atomic updates need distributed transactions: slower, can become a bottleneck                  |
| Operations           | Rebalancing, routing, hot spots                                                                |

Sharding inside one machine (one single-threaded process per core, NUMA-aware) is a valid pattern for CPU parallelism.

## Sharding for multitenancy

One shard per tenant, or small tenants grouped into shared shards.

Benefits:

- Resource isolation: a heavy tenant hurts fewer neighbors.
- Permission isolation: an access-control bug is less likely to leak across tenants.
- Cell-based architecture: shard the services too; a fault stays inside one cell.
- Per-tenant backup and restore.
- Privacy compliance: export or delete one person's or tenant's data as a unit.
- Data residency: pin a tenant's shard to a region.
- Gradual schema rollout per tenant (hard to make transactional).

Challenges:

- A tenant too big for one node needs sharding inside the tenant.
- Many tiny tenants: per-shard overhead is high; grouping them requires a way to move tenants as they grow.
- Cross-tenant features need cross-shard joins.

## Key-range sharding

- Each shard owns a contiguous, sorted range of keys. Boundaries adapt to data (manual or automatic).
- Within a shard keys are sorted (B-tree / SSTables), so range scans and concatenated-key queries are cheap.
- **Hot spot risk**: monotonically increasing keys (timestamps, sequential IDs) send all current writes to one shard.
  - Fix: prefix the key with a high-cardinality value (e.g., device ID, then timestamp). Cost: a time-range query across many prefixes becomes one range query per prefix.
- Rebalancing: split a shard when it grows too big or too hot; merge adjacent small shards after deletions. Number of shards follows the data.
- Empty database starts with one shard unless you **pre-split**, which needs a guess at the key distribution.

## Hash-based sharding

- Hash the partition key, then map the hash to a shard. Use when locality of nearby keys does not matter (e.g., tenant IDs).
- Hash function: need not be cryptographic, but must be **stable across processes and versions**. Language built-in object hashes are often seeded per process: never use them.
- **Never use hash mod N nodes**: adding a node moves almost every key.

### Hash-based options

| Scheme                                         | How                                                                                                                             | Pros                                                                           | Cons                                                                                                                                 |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| Fixed number of shards                         | Create many more shards than nodes (e.g., 1000 for 10 nodes); key goes to hash mod shard-count; move whole shards between nodes | Simple; only shard-to-node map changes; weight powerful nodes with more shards | Must guess count up front; shard size grows with data; more nodes than shards impossible; resharding is costly and may need downtime |
| Hash-range                                     | Each shard owns a contiguous range of hash values; split ranges when big or hot                                                 | Shard count adapts to data; even spread of sequential keys                     | No efficient range queries on the partition key                                                                                      |
| Random-boundary ranges per node                | Each node owns several hash ranges with randomly chosen boundaries; range count grows with nodes                                | New node takes parts of existing ranges; imbalance evens out                   | Ranges uneven in size individually                                                                                                   |
| Consistent hashing variants (rendezvous, jump) | New node takes individual keys from all nodes                                                                                   | Minimal movement, even key spread                                              | Moves scattered keys, not contiguous ranges                                                                                          |

"Consistent" in consistent hashing means keys tend to stay put. It has nothing to do with replica consistency or ACID consistency.

Pick a shard count that divides evenly by many numbers, so the data spreads across different node counts.

Compound primary keys: if only the first column is the partition key, range queries on later columns within the same partition key stay on one shard and are efficient. Warehouses apply the same idea as partition key plus cluster/sort keys (better range scans, compression, filtering).

## Key-range vs hash sharding

| Concern                          | Key-range                                     | Hash (incl. hash-range)                      |
| -------------------------------- | --------------------------------------------- | -------------------------------------------- |
| Range scan on partition key      | Efficient                                     | Scatter to all shards                        |
| Sequential-key write hot spot    | Yes                                           | No                                           |
| Even data distribution           | Needs adaptive boundaries                     | Natural                                      |
| Shard count adapts to data       | Yes (split/merge)                             | Hash-range: yes; fixed shards: no            |
| Pre-split needed for an empty DB | Usually                                       | Hash-range: optional; fixed shards: built in |
| Good fit                         | Time series with prefixed keys, ordered scans | Point lookups by ID, tenant IDs              |

## Skew and hot keys

Even hashing only balances **keys**. Load can still be skewed: one key can have very large data or a very high request rate (e.g., a celebrity's post).

Mitigations:

- With range-based shards (key or hash ranges), isolate one hot key in its own shard or even on a dedicated node.
- **Key salting**: append a small random suffix (e.g., 2 digits gives 100 sub-keys) to spread writes. Costs:
  - Reads must fetch all sub-keys and combine them; read load per sub-key shard is not reduced.
  - Do it only for known hot keys; needs bookkeeping of which keys are split and a way to convert keys at runtime.
- Hotness changes over time, and read-hot and write-hot keys need different treatment.
- Some managed services rebalance hot shards automatically (adaptive capacity / heat management).

## Rebalancing operations

Requirements: load ends up fair; reads and writes continue during the move; move no more data than needed.

| Mode                     | Pros                                                     | Cons                                                                                                                                                                                                                            |
| ------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fully automatic          | Low ops effort; can autoscale with load                  | Unpredictable; moving data loads network and nodes; may not keep up near max write throughput; combined with automatic failure detection can cause **cascading failure** (slow node declared dead, load moves, others overload) |
| Suggested + human commit | Human checks the plan                                    | Slower                                                                                                                                                                                                                          |
| Manual                   | Predictable; can rebalance ahead of known traffic events | Ops effort; slow reaction                                                                                                                                                                                                       |

Rule: keep a human in the loop for rebalancing, or at least rate-limit it and decouple it from failure detection.

During a move the old assignment keeps serving until cutover.

## Request routing

Problem: find the node that owns the shard for a key. Unlike stateless services, only nodes that hold the shard can serve.

| Approach           | How                                                                      | Trade-off                                    |
| ------------------ | ------------------------------------------------------------------------ | -------------------------------------------- |
| Any node forwards  | Client hits any node (round-robin); node forwards if it is not the owner | Extra hop; every node needs the map          |
| Routing tier       | Shard-aware proxy forwards requests                                      | Extra component and hop; clients stay simple |
| Shard-aware client | Client connects straight to owner                                        | Lowest latency; client must track the map    |

Questions every design must answer:

- Who decides shard placement? A single coordinator must be fault-tolerant without split brain (two coordinators with conflicting assignments).
- How does the router learn about changes?
- How are in-flight requests handled at cutover, when the old owner still receives requests?

Common answers:

- A consensus-backed coordination service (e.g., ZooKeeper, etcd) holds the authoritative shard-to-node map; routers subscribe to changes. Many systems now embed Raft for this.
- Gossip protocols spread cluster state with weak consistency; split brain is possible. Acceptable only in systems that already give weak guarantees (leaderless).
- Node IP discovery changes slowly: DNS is usually enough.

Analytical systems use sharding differently: one query fans out to many shards in parallel and aggregates. Routing by key matters most for OLTP.

## Secondary indexes in sharded systems

Secondary indexes do not map to a shard by the partition key. Two approaches:

| Property            | Local (document-partitioned)                                                               | Global (term-partitioned)                                                   |
| ------------------- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| Index lives         | On each shard, covering only that shard's records                                          | Separate, sharded by indexed value (term), by range or hash                 |
| Write cost          | Touch one shard                                                                            | Touch possibly several index shards per record                              |
| Index freshness     | Updated with the record (same shard)                                                       | Often async, so reads can be stale; or needs a distributed transaction      |
| Read by one value   | Scatter/gather to all shards (unless partition key known, or any partial result is enough) | One index shard for the postings list, then fetch records from their shards |
| Multi-condition AND | Each shard computes locally                                                                | Intersect postings lists across shards; slow if lists are long              |
| Scalability         | Adding shards adds storage, not query throughput; tail latency grows with fan-out          | Scales reads when lists are short                                           |
| Prefer when         | Write-heavy; queries usually include the partition key                                     | Read-heavy; selective terms with short postings lists                       |

Rules:

- Rolling your own secondary index in a key-value store (value-to-ID map in app code) drifts out of sync on races and partial failures. Use the database's indexes or atomic multi-key writes.
- If a global index is async, treat its reads as replica reads with lag: apply the replication-lag guarantees.
- Design the partition key so the most frequent queries include it, which avoids scatter/gather.

## Review checklist

- Is sharding necessary? Are data size and write rate beyond one node, or do read replicas suffice?
- What is the partition key? Do the main queries include it? Which queries become scatter/gather?
- Are there sequential keys (timestamps, autoincrement) under key-range sharding? Is there a prefix to spread writes, and is the query cost of that accepted?
- Is hash mod N or a per-process-seeded hash used anywhere?
- If fixed shard count: is the count large enough for future node counts, and evenly divisible? What is the resharding plan?
- Which keys can become hot (celebrities, viral items, big tenants)? Is there a plan (isolation, salting with read fan-in, managed heat management)?
- Is rebalancing automatic? Is it rate-limited and separate from failure detection, to prevent cascading failures?
- How does routing learn shard ownership? Is the map in a consensus system or gossip? How are in-flight requests handled at cutover?
- Local or global secondary indexes? Is staleness of global indexes acceptable? Is fan-out tail latency acceptable for local ones?
- Do any writes need atomicity across shards? Is a distributed transaction affordable, or can the data model keep them on one shard?
- Multitenancy: can the biggest tenant outgrow a shard? How are small tenants grouped and moved? Are residency, per-tenant restore, and deletion needs met?
