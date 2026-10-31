# Consistency and Consensus

Covers DDIA 2nd ed., Chapter 10 (Consistency and Consensus).

## Consistency models: the spectrum

| Model                                | Guarantee                                                                                            | Cost                                               | Survives partition on minority side |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- | -------------------------------------------------- | ----------------------------------- |
| Eventual consistency                 | Replicas converge if writes stop; reads may be stale or go backward                                  | Cheapest; local reads and writes                   | Yes                                 |
| Causal consistency                   | Effects never visible before their causes; concurrent ops may be seen in different orders            | Moderate; track dependencies                       | Yes, the strongest model that does  |
| Linearizability (strong consistency) | System behaves as one copy; every op takes effect atomically at some instant between call and return | Coordination per op; latency tied to network delay | No                                  |

- Rule: start from the weakest model that keeps invariants. Pay for linearizability only where a single up-to-date answer is required.
- Eventual consistency forces the application to handle stale reads, read-your-writes gaps, and conflicts. That complexity moves to the app; account for it.

## Linearizability

- Definition: once any read has returned a new value, every later read (by any client, in real time) must return that value or a newer one. A recency guarantee on a single object (register).
- Testable by checking whether some total order of operations is consistent with real-time order and the register semantics.
- **Not the same as serializability**. Serializability: transactions over many objects behave as if run in some serial order, which need not match real time. Linearizability: single-object real-time recency, no transactions. Both together = strict serializability. Serializable snapshot isolation is not linearizable (reads from a snapshot are stale by design).

When you need it:

- Leader election and distributed locks: all nodes must agree who holds it.
- Uniqueness constraints (username, file path, seat, account not overdrawn): need a single up-to-date view at decision time.
- Cross-channel timing dependencies: one system writes and sends a message through another path (queue, notification); the receiver reads and must see the write. If replication lags, the receiver sees old data. Fix with linearizable reads or by passing the data or version in the message.

Which replication schemes give it:

| Scheme                                                   | Linearizable?                                                                                                                                                              |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Single-leader, reads from leader or synchronous follower | Potentially, if no split brain and leader identity is certain                                                                                                              |
| Consensus-based replication                              | Yes, when reads also go through the quorum or the leader confirms leadership                                                                                               |
| Multi-leader                                             | No; concurrent writes on different nodes                                                                                                                                   |
| Leaderless with quorums                                  | Usually no: clock-based LWW, sloppy quorums, and lagging read repair break it. Achievable only with synchronous read repair and no LWW, and even then CAS is not supported |

## The cost of linearizability and CAP

- During a network fault, a linearizable system must make the cut-off nodes refuse requests (or wait). A non-linearizable system can keep serving each side and reconcile later.
- CAP framing that is actually useful: when a partition happens, choose linearizability or availability. Not "pick two of three": partitions are not optional.
- CAP is narrow: one consistency model, one fault type, no latency. It says little about real designs; do not use it as a design tool. Better framing: consistency vs availability under partition, and consistency vs latency always.
- Linearizability is slow even without faults: response time has a lower bound proportional to network delay uncertainty. Many systems (including multi-core CPU memory) drop it for performance, not for fault tolerance.

## ID generation

| Scheme                                                                       | Unique                 | Ordered                               | Notes                                                                       |
| ---------------------------------------------------------------------------- | ---------------------- | ------------------------------------- | --------------------------------------------------------------------------- |
| Single-node auto-increment                                                   | Yes                    | Linearizable                          | Single point of failure; cross-region latency; throughput bottleneck        |
| Sharded ranges (bits reserve a shard number, odd/even)                       | Yes                    | No                                    | Compact                                                                     |
| Preallocated blocks per node                                                 | Yes                    | No                                    | Fewer round trips to the allocator                                          |
| Random UUID (v4)                                                             | Probabilistically      | No                                    | 128 bits; no coordination; poor index locality                              |
| Timestamp prefix plus shard or random suffix (UUIDv7, Snowflake-style, ULID) | Yes                    | Approximate only                      | Inherits clock skew and backward jumps                                      |
| Lamport timestamp                                                            | Yes (counter, node ID) | Total order consistent with causality | No relation to physical time                                                |
| Hybrid logical clock                                                         | Yes                    | Causal, and close to wall time        | Needs roughly synced clocks only                                            |
| Linearizable ID generator (single replicated node, timestamp oracle)         | Yes                    | Linearizable                          | Cannot shard or spread across regions; batch persisted allocations to scale |
| Clock with uncertainty interval plus commit-wait                             | Yes                    | Linearizable                          | Needs tight clock sync hardware                                             |

Logical clocks:

- **Lamport**: each node keeps a counter; on every event increment; on receiving a timestamp, jump to max(local, received) then increment. Tie-break with node ID. Order is consistent with happens-before, but you cannot tell concurrent from sequential.
- **Hybrid logical clock**: physical-time units, but moves forward to any larger seen timestamp and always increments, so it never goes backward. Usable as a near-wall-clock timestamp that respects causality. Good for MVCC transaction IDs.
- **Vector clock**: one counter per node. Detects concurrency (neither dominates). Size grows with node count. Use only if you must detect concurrent writes.

Limits:

- Lamport and HLC ordering is weaker than linearizable: two nodes that never communicate can assign out-of-real-time-order stamps. Failure mode: a user changes a privacy setting on one shard, then uploads to another shard; the upload gets a lower timestamp; a snapshot read between the two stamps shows the upload under the old setting. Fix: linearizable ID generator, or make the write read the dependency first.
- Even a linearizable ID generator cannot by itself enforce uniqueness or locks: to know your stamp is lowest, you must hear from every possible competitor. One unreachable node blocks everyone. That needs consensus.

## Consensus: the problem and its equivalent forms

- Single-value consensus properties: **uniform agreement** (no two nodes decide differently), **integrity** (decide once), **validity** (decided value was proposed), **termination** (every non-crashed node eventually decides). The first three are safety; termination is liveness.
- Requires a majority alive and communicating. Impossible to guarantee deterministically in a purely asynchronous model (FLP); practical algorithms use timeouts or randomness to escape.

These are all equivalent (a fault-tolerant solution to one gives the others):

| Form                                  | What it decides                                                                     |
| ------------------------------------- | ----------------------------------------------------------------------------------- |
| Single-value consensus                | One value among proposals                                                           |
| Linearizable compare-and-set register | Whether my write wins given the expected old value                                  |
| Shared log / total order broadcast    | The order of all appended entries; every node sees same order, no gaps, append-only |
| Atomic commitment                     | Commit or abort for a distributed transaction (abort if any participant votes no)   |
| Lock / lease acquisition              | Which client holds it                                                               |
| Leader election                       | Which node leads in an epoch                                                        |
| Uniqueness constraint                 | Which claimant gets the name                                                        |

- Fetch-and-add is weaker: it only solves consensus for two nodes. A fault-tolerant counter is not enough for general agreement.
- Atomic commitment via consensus: each participant proposes its vote into the shared log; decide commit only if all yes votes appear before any abort or timeout entry. This replaces the 2PC coordinator's blocking single decision.

## Consensus in practice

- Most consensus systems expose a shared log (Raft, Multi-Paxos, Zab, Viewstamped Replication). Shared log enables state machine replication: deterministic replicas applying the same log converge.
- From the log you can derive: CAS (first entry wins), per-key consensus (first entry naming a seat wins), fetch-and-add (sum of entries), fencing tokens (log position).
- Mechanism: epoch numbers (term, ballot, view). Within one epoch the leader is unique. A higher epoch beats a lower one. Two rounds of quorum voting: elect the leader, then accept each entry. Quorums must overlap so the leader learns about any newer epoch before appending.
- Differs from 2PC: any node can start an election; a quorum suffices; 2PC needs every participant and only the coordinator asks.
- New leader must have every committed entry before serving writes or linearizable reads. Raft restricts who may win; Paxos lets anyone win but forces catch-up first.
- Linearizable reads also need a quorum round (or equivalent leadership check). Reading from the self-believed leader alone is not linearizable.
- Membership changes need explicit reconfiguration support.

Weakening consensus:

- Options such as unclean leader election (a lagging replica may become leader) or asynchronous failover trade safety for availability. Outside the theory: data loss and divergence under faults. Choose explicitly and document the loss window.
- Rule: any automatic failover not built on a proven consensus algorithm is presumed unsafe.

Costs:

| Cost           | Detail                                                                                                      |
| -------------- | ----------------------------------------------------------------------------------------------------------- |
| Node count     | Strict majority: 3 nodes tolerate 1 failure, 5 tolerate 2                                                   |
| Throughput     | Every op hits a quorum; adding nodes slows it, does not scale it                                            |
| Partitions     | Minority side blocks                                                                                        |
| Timeouts       | Hard to tune across regions; too short causes election storms, too long slows recovery                      |
| Network quirks | A single flaky link can make leadership bounce; pre-vote extensions help                                    |
| Sharding       | Per-shard logs scale but weaken cross-shard guarantees (snapshots, foreign keys) without extra coordination |

## Coordination services

- Category: small, in-memory, consensus-replicated key-value stores built to coordinate other systems (ZooKeeper, etcd, Consul; modeled on a lock service design). Not a general database; low write volume.
- Features: locks and leases via consensus CAS; fencing tokens from monotonically increasing log or revision IDs; session heartbeats with ephemeral keys that vanish when the client dies; change notifications (watches).
- Failure detection and notifications do not need consensus but are convenient alongside it.

Uses:

- Leader or primary election for databases, schedulers, stateful services.
- Shard-to-node assignment and rebalancing as nodes join or leave.
- Service discovery (often does not need linearizability; stale reads acceptable).
- Configuration distribution with watch-based reload (consensus not required; a polled file or URL also works).

Rules:

- Use a coordination service instead of writing your own consensus or failover logic.
- Keep it a small, fixed set of nodes (3 or 5); many clients can use it.
- Store slow-changing coordination data only; never hot data paths.
- Always pair a lease with a fencing token checked at the resource.

## Review checklist

- Which operations truly need linearizability (locks, leader identity, uniqueness, cross-channel reads)? Is everything else on a cheaper model?
- Is "strong consistency" claimed for a leaderless or multi-leader store, or for reads that skip the quorum?
- Is any message sent through a side channel (queue, webhook) that the receiver uses to read possibly stale replicas?
- What does each component do on the minority side of a partition: refuse, block, or serve stale data? Is that chosen on purpose?
- Are IDs expected to reflect creation order? Does the chosen generator actually guarantee that order (linearizable, causal, or approximate)?
- Are timestamp-prefixed IDs or HLCs used where linearizable order is required for permission or visibility decisions?
- Is any uniqueness, lock, or leader decision made without consensus (for example, "lowest timestamp wins", homemade heartbeat failover)?
- Does failover permit an out-of-date replica to become leader? What data loss is accepted?
- Are consensus timeouts tuned for the real latency distribution, including cross-region?
- Is the coordination service sized as 3 or 5 nodes and kept off hot paths?
- Are leases from the coordination service paired with fencing tokens enforced by the resource?
- For cross-shard invariants, what extra coordination is in place beyond per-shard logs?
