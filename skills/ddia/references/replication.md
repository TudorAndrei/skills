# Replication

Covers DDIA 2nd ed., Chapter 6 (Replication).

## Why replicate (state which one applies)

- High availability: keep serving when a node, zone, or region fails.
- Durability: survive loss of a disk or machine. Replication is not a backup: it copies deletes and corruption too. Keep backups as well.
- Latency: place copies near users.
- Read scaling: spread reads over many replicas.
- Disconnected operation: keep working offline (devices as replicas).
  All the difficulty is in handling **changes** to replicated data.

## Approach comparison

| Property                     | Single-leader                         | Multi-leader                                        | Leaderless                                          |
| ---------------------------- | ------------------------------------- | --------------------------------------------------- | --------------------------------------------------- |
| Who accepts writes           | One leader per data set (per shard)   | Several leaders (per region, per device)            | Any replica; client or coordinator sends to many    |
| Write conflicts              | None (leader orders writes)           | Yes, must be resolved                               | Yes, must be resolved                               |
| Strong consistency possible  | Yes (read from leader / sync replica) | No, without extra coordination                      | No, quorums are probabilistic                       |
| Failure handling             | Failover (risky, causes a pause)      | Other leaders keep going                            | No failover; tolerates slow/dead nodes              |
| Write latency across regions | High for remote clients               | Low (local leader)                                  | Tunable (local quorum)                              |
| Network partition tolerance  | Weak for side without leader          | Strong                                              | Medium-strong (sloppy quorum option)                |
| Complexity                   | Lowest                                | High (conflicts, topology)                          | Medium-high (quorums, repair, versioning)           |
| Typical fit                  | Most OLTP; default choice             | Multi-region writes, offline clients, collaboration | High availability KV stores, tail-latency sensitive |

Default: single-leader, unless a requirement (offline writes, write locality across regions, no failover pauses) forces otherwise.

## Single-leader replication

- Leader writes locally, then sends changes to followers via a replication log. Clients may read from any replica.

### Synchronous vs asynchronous

| Mode                                 | Durability on leader loss              | Write availability                         | Latency |
| ------------------------------------ | -------------------------------------- | ------------------------------------------ | ------- |
| Fully synchronous                    | No loss                                | One slow follower blocks all writes        | Highest |
| Semi-synchronous (one sync follower) | Data on at least two nodes             | Promote another follower to sync if needed | Medium  |
| Fully asynchronous                   | Recent acknowledged writes can be lost | Leader never waits                         | Lowest  |

- Async is common, especially with many followers or across regions. Then an acknowledged write is **not durable** until replicated. State that explicitly.

### Adding a follower

Take a consistent snapshot without locking, copy it, then replay the log from the snapshot's exact log position. Needs a snapshot tied to a log position.

### Databases backed by object storage

- Object stores give cheap, highly durable, multi-zone storage and a conditional write (compare-and-set) that can implement leader election and commits.
- Costs: much higher latency than local disk, per-request fees push batching (more latency), objects are immutable (random writes are expensive), file system interfaces are partial.
- Designs: tiered storage (hot data on local SSD, cold on object store); object store as primary with a separate low-latency WAL; zero-disk (stateless nodes, disks only as cache).

### Follower failure

Catch-up from its last applied log position. Make sure the leader retains enough log.

### Leader failure: failover

Steps: detect failure (usually timeout), choose new leader (election or controller; best candidate is the most up-to-date replica), reconfigure clients and old leader.

Failure modes:

- Async replication: new leader lacks writes the old leader acknowledged. Discarding them breaks durability promises.
- Discarded writes are dangerous when other systems saw them (e.g., reused auto-increment IDs that an external cache or store already used: data leaks between records).
- **Split brain**: two nodes both think they are leader. Need fencing; shutting down one node blindly can kill both.
- Timeout choice: too long means long outage; too short means needless failovers under load spikes, which make overload worse.
  Rule: many teams prefer manual failover for these reasons. Automatic failover needs fencing and a consensus-based leader election.

### Replication log formats

| Method                    | How                                             | Problems                                                                                           |
| ------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Statement-based           | Ship SQL statements                             | Nondeterminism (NOW(), RAND(), autoincrement order, triggers, side effects) diverges replicas      |
| WAL shipping              | Ship storage-engine byte changes                | Coupled to storage format and version: usually no mixed-version cluster, so upgrades need downtime |
| Logical (row-based)       | Ship row-level insert/update/delete with values | Few; decoupled from engine; enables mixed versions and change data capture                         |
| Trigger-based / app-level | Custom code copies changes                      | Flexible but slow and bug-prone                                                                    |

Prefer logical logs. They also feed CDC to warehouses, caches, and search indexes.

## Replication lag anomalies and guarantees

With async followers, reads can be stale. "Eventual" has no time bound; lag can grow to minutes under load or faults. Design for that.

| Guarantee                           | Anomaly prevented                                                                | How to provide it                                                                                                                                                                                                                                                    |
| ----------------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Read-after-write (read-your-writes) | User writes, then reads a replica that lacks the write; the write seems lost     | Read data the user can modify from the leader; or read from leader for a time window after the user's last write; or client remembers last write's log position/timestamp and only reads replicas caught up to it; route to the region of the leader if multi-region |
| Cross-device read-after-write       | Same user on another device sees old data                                        | Store last-write metadata on the server, not per device; route all of a user's devices to the same region                                                                                                                                                            |
| Monotonic reads                     | User sees new data, then old data (time goes backward) when hitting two replicas | Pin each user to one replica (e.g., hash of user ID); reroute on replica failure                                                                                                                                                                                     |
| Consistent prefix reads             | Reader sees an effect before its cause (answer before question)                  | Write causally related data to the same shard / same log; or track causal dependencies                                                                                                                                                                               |

Rules:

- Ask: "what does the user see if lag becomes one hour?" If that is not acceptable, provide one of these guarantees explicitly.
- App-level workarounds are complex and fragile. The simpler option is a database with linearizability and transactions; use weaker replication only when you need its resilience or low overhead.
- Consistent prefix is mainly a sharded-system problem: different shards apply writes independently.

## Multi-leader replication

Use cases:

- **Multi-region**: one leader per region. Local write latency; each region survives the loss of others; tolerates inter-region network problems because replication is async.
- **Offline clients**: each device's local DB is a leader. Lag can be days.
- **Real-time collaboration**: each open editor is a replica; edits apply locally first.

Costs: conflicts, and features that assume one writer (autoincrement keys, triggers, integrity constraints) break. Avoid multi-leader inside one region.

### Topologies

| Topology                                                                                 | Risk                                                                                                             |
| ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| All-to-all                                                                               | Writes can arrive out of order (update before the insert it depends on); needs causal ordering (version vectors) |
| Circular / star                                                                          | One failed node breaks the path; reconfiguration often manual                                                    |
| Each node tags writes with the IDs of nodes they passed through, to stop infinite loops. |

### Sync engines and local-first software

- A sync engine keeps persistent state on the client and syncs in the background. Offline is just a long delay.
- Gains: instant UI, offline work with no special mode, simpler client code (local reads/writes rarely fail), real-time updates with a reactive UI.
- Limit: client must hold all data the user may need. Fine for a user's own documents; wrong for a large shared catalog.
- **Local-first**: works even if the vendor's servers go away; needs an open sync protocol with several providers.

## Conflict handling

Options in order of preference:

1. **Avoid**: route all writes for a record to one designated leader (e.g., user's home region). Breaks when the home leader changes.
2. **Automatic merge** with convergence (strong eventual consistency): all replicas that saw the same writes reach the same state, in any order.
3. **Manual**: store all concurrent values (siblings), let the app or user merge on read.
4. **Last write wins (LWW)**: keep the value with the highest timestamp.

| Method                     | Data loss                                                                           | Notes                                                                                                                             |
| -------------------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| LWW                        | Yes, silently drops concurrent writes; clock skew can drop even non-concurrent ones | Safe only for immutable data written once (e.g., key is a UUID) or when loss is acceptable                                        |
| Siblings + app merge       | No, if merge is correct                                                             | Merge logic is easy to get wrong (shopping cart: union merge resurrects deleted items unless deletes leave tombstones); UI burden |
| CRDT                       | No (for supported types)                                                            | Unique immutable IDs per element; merges commute; used in databases and JSON sync engines                                         |
| Operational transformation | No                                                                                  | Transforms indexes of concurrent ops; common for collaborative text                                                               |

Mergeable types: text, ordered lists, sets (track deletes), counters (sum per-replica increments), maps (merge per key).
Limit: invariants spanning items (e.g., "at most N items", "no overlapping room bookings") cannot be enforced by merge. These need coordination (see transactions, consensus).
Subtle conflicts: two inserts of different records can violate a constraint together. Detecting them needs app knowledge.

## Leaderless replication (Dynamo style)

- Client (or coordinator node) sends each write to all n replicas and each read to several replicas. Version numbers pick the newest value.

### Repair of missed writes

| Mechanism      | How                                                               | Gap                                           |
| -------------- | ----------------------------------------------------------------- | --------------------------------------------- |
| Read repair    | Reader writes newest value back to stale replicas                 | Only for keys that are read                   |
| Hinted handoff | Another replica stores writes for a down node, delivers on return | Adds load when the system is already stressed |
| Anti-entropy   | Background process compares replicas                              | Not ordered; may be slow                      |

### Quorums

- n replicas, write waits for w acks, read waits for r responses. If w + r > n, read and write sets overlap. Common: n odd, w = r = ceil((n+1)/2). Quorums need not be majorities, only overlapping.
- Tolerates n - w unavailable nodes for writes, n - r for reads. Small w, r: lower latency, higher availability, more stale reads.
- In practice quorums rarely exceed about 4-of-7 or 5-of-9; bigger quorums hit slow nodes more often.

Edge cases where w + r > n still returns stale data:

- Node with new value fails and is restored from a stale replica.
- Rebalancing in progress: nodes disagree on which n nodes hold a key.
- Read concurrent with write: one read may see new, a later read old.
- Write failed overall (fewer than w acks) but is not rolled back on nodes where it succeeded.
- LWW with clock timestamps silently drops writes.
- Concurrent writes applied in different orders on different replicas.
  Rule: treat quorums as tuning the probability of staleness, not a guarantee. They do not give linearizability.

### Sloppy quorum

If home replicas are unreachable, accept writes on any reachable node. Raises write availability; no guarantee later reads see the write.

### Monitoring staleness

Leader-based: lag = leader log position minus follower position. Leaderless: no fixed order, hard to measure (hint backlog is a weak signal). Quantify "eventual" anyway and alert on it.

### Single-leader vs leaderless performance

- Leader: read-from-leader caps read throughput; failover causes visible pauses; a slow (gray-failing) leader slows everything and forces a hard failover decision.
- Leaderless: no failover; parallel requests let the client use the fastest responses (**request hedging**), cutting tail latency; gray failures barely matter.
- Leaderless costs: hint storage and handoff under stress; large quorums raise latency; a wide network failure can block quorums.

### Multi-region leaderless

Options: quorum across all regions, quorum per region, or local-region quorum only (fast, staler). Some systems keep n per region and replicate between regions asynchronously, like multi-leader.

## Detecting concurrent writes

- **Happens-before**: A happens before B if B knew about or built on A. If neither knows of the other, they are **concurrent**, regardless of wall-clock time. Concurrent writes are conflicts; ordered writes are not.
- Single-replica algorithm: server keeps a version number per key. Client must read before write and send back the version it saw. Server overwrites values at or below that version and keeps higher ones as siblings. Writes with no version are concurrent with everything.
- Multi-replica: **version vector** = one counter per replica. Compare vectors to decide overwrite vs sibling. Clients pass the vector back with writes.
- Deletes need **tombstones** so merges do not resurrect data.
- Version vectors are not vector clocks in the strict sense; both track causality. Wall-clock timestamps cannot detect concurrency.

## Review checklist

- Which replication approach, and which requirement justifies anything other than single-leader?
- Sync, semi-sync, or async? Can an acknowledged write be lost on leader failure, and does the product accept that?
- Is failover automatic? How is split brain prevented (fencing, consensus)? What is the failure detection timeout and why?
- Do external systems use IDs or data that a failover could roll back?
- Which replication log format? Can the cluster run mixed versions during upgrades?
- Which reads hit followers? For each, which guarantee is needed: read-after-write (incl. cross-device), monotonic reads, consistent prefix? How is it provided?
- What happens to users if lag reaches minutes or hours? Is lag monitored and alerted?
- Multi-leader: what is the conflict strategy per data type? Is LWW used where data loss is unacceptable? Are deletes tombstoned?
- Are there cross-record invariants (uniqueness, limits, no overlap) that merges cannot preserve?
- Leaderless: what are n, w, r per operation? Is anyone treating w + r > n as strong consistency? Are sloppy quorums on?
- How are missed writes repaired (read repair, hinted handoff, anti-entropy) and is cold data covered?
- How are concurrent writes detected (version vectors) vs guessed (timestamps)?
- Is there a backup separate from replication?
- Object-storage-backed: is the latency and per-request cost accounted for? Where does the WAL live?
- Sync engine: does the client data set fit on the device? Is there an open sync protocol if local-first is a goal?
