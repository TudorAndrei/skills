# Distributed Faults

Covers DDIA 2nd ed., Chapter 9 (The Trouble with Distributed Systems).

## Partial failure is the default

- On one machine, faults tend to be total and deterministic. Across machines, some parts fail while others run, and failures are nondeterministic. You often cannot even tell whether something failed.
- Design stance: assume every message, clock read, and pause can go wrong; build fault tolerance in software from unreliable parts. Suspicion, not certainty, is the normal state.
- Single-node HPC-style "checkpoint and restart the whole job" does not fit online services that must stay available.

## Unreliable networks

- Packet-switched networks are asynchronous: no bound on delivery time and no delivery guarantee.
- When a request gets no reply, you cannot distinguish: request lost, request queued, remote node dead, remote node paused, reply lost, reply queued. All look the same.
- TCP retransmits and orders bytes, but it does not tell you whether the remote application processed the data. A closed connection after send means "unknown", not "failed". Only an application-level ack tells you success.
- Network faults are common in practice, including one-way faults and partitions within one datacenter. Software must handle them even if rare; test by deliberately injecting them.

## Fault detection and timeouts

- Explicit failure signals exist sometimes (connection refused, process-crash notification, switch link down) but cannot be relied on. A timeout is the only general detector, and it can only produce suspicion.
- Timeout too short: false positives, so work moves to another node, the load increases, and the cluster can cascade into failure; an action can run twice. Too long: slow recovery and long user waits.
- Delay variability comes from queueing: switch queues, OS receive buffers, VM scheduling, TCP flow control and congestion backoff, noisy neighbours in shared clouds.
- Rules:
  - Measure the round-trip distribution and its jitter; choose timeouts from data. Prefer adaptive detectors (for example, phi-accrual style) over fixed constants.
  - Treat a declared-dead node as possibly alive. Anything it does after being declared dead must be safe (see fencing).
  - Under latency-sensitive load, UDP plus app-level handling may beat TCP retransmission for data that goes stale fast.
- Bounded latency needs circuit-switched style reservation. Datacenter networks and the internet optimize utilization via packet switching instead, so unbounded delay is a cost-driven trade-off, not a fixable bug.

## Clocks

| Clock                                     | What it measures                                | Safe for                                           | Not safe for                                                                    |
| ----------------------------------------- | ----------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------- |
| Time-of-day (wall clock)                  | Seconds since epoch, synced by NTP              | Displaying time, approximate timestamps for humans | Measuring elapsed time; ordering events across nodes; deciding which write wins |
| Monotonic                                 | Arbitrary-origin counter that only goes forward | Elapsed time, timeouts, durations on one node      | Comparing values across nodes (meaningless)                                     |
| Logical (Lamport, hybrid logical, vector) | Event order, not time                           | Ordering consistent with causality                 | Answering "what time is it" (pure Lamport)                                      |
| Clock with confidence interval            | Earliest and latest possible true time          | Commit-wait ordering of transactions across nodes  | Anything, if the interval bounds are wrong                                      |

Pitfalls:

- Wall clocks jump backward or forward when NTP resyncs; leap seconds and smearing create odd intervals.
- Quartz drift is tens of ppm; a node cut off from NTP drifts quickly. NTP accuracy is bounded by network delay; misconfigured firewalls, wrong NTP servers, and VM pauses make clocks silently wrong.
- A wrong clock rarely crashes anything. It silently corrupts ordering. Monitor clock offset on every node and evict nodes that drift past a threshold.
- **Last-write-wins with wall-clock timestamps** can drop writes that causally came later if they were stamped on a slower clock. A node with a fast clock can dominate others' writes. LWW cannot tell "sequential" from "truly concurrent". Prefer logical clocks for ordering.
- A timestamp reading has an error bar. Treat it as a range. Most APIs hide the range; few systems expose it.
- **Global snapshots by clock**: possible only if the clock reports bounded uncertainty and transactions wait out the interval before commit (the commit-wait approach used by a globally distributed database with GPS and atomic clocks). Wait time is proportional to uncertainty, so tight sync matters.

## Process pauses

- Any thread can be stopped for an unbounded time at any instruction: stop-the-world GC, VM suspend or live migration, steal time on shared hosts, laptop sleep, OS context switches, disk I/O on a page fault or swap, synchronous log flush to a slow disk, SIGSTOP.
- Consequence: code that checks a condition, then acts, can act long after the condition stopped being true. A node that thought it held a lease may resume after the lease expired, with no notion that time passed.
- Mitigations:
  - Treat GC pauses as planned outages: warn peers ahead, drain requests, or restart processes before old-generation pressure builds.
  - Use runtimes with bounded pauses, or limit allocation in hot paths.
  - Hard real-time systems guarantee deadlines at the cost of throughput and require specific language and OS support; usually not worth it outside safety-critical control.
- Never use `wall_now() < lease_expiry` from a local clock as the only guard on a protected action.

## Truth is decided by a quorum

- A node cannot trust its own view: it may be cut off, paused, or declared dead by the others while it still believes it is fine.
- Decisions (is this node dead, who is leader, who holds the lock) belong to a quorum, normally a strict majority. Overlapping majorities make two conflicting decisions impossible.
- When the quorum declares a node dead, it must step down even if it feels healthy.

## Distributed locks, leases, and fencing tokens

- A lease is a lock with a timeout, so a dead holder does not block forever. Classic failure: holder pauses, lease expires, another client takes it, original holder resumes and writes, corrupting the shared resource.
- **Fencing token**: the lock service hands out a number that strictly increases with each grant. Every write to the protected resource carries the token. The resource rejects any write whose token is lower than the highest it has seen.
- The check must happen at the resource, not at the client. Clients cannot police themselves.
- If the resource cannot check tokens natively: encode the token in the object path or name, or use a conditional write (compare-and-set on a version) that achieves the same effect.
- With a replicated, leaderless resource, fencing gets harder: a stale write may reach some replicas. Use token-as-timestamp so newer tokens win on each replica, and make writes go through quorums.
- A lock service with consensus can supply tokens from its log sequence number or version counter.

## Byzantine faults

- Byzantine = a node may send arbitrary or malicious messages, not just crash or delay.
- Byzantine-tolerant protocols need more than two-thirds honest nodes and are expensive. Worth it in aerospace hardware exposed to radiation and in systems with mutually distrusting parties (blockchains). Usually not worth it inside one organization, where all nodes run the same code, so a software bug defeats replication anyway.
- Cheap protections against "weak lying" are still worth it: checksums at the application layer, input validation and sanity checks, multiple NTP servers with outlier rejection.

## System models

Timing models:

| Model                 | Assumption                           | Realism                                      |
| --------------------- | ------------------------------------ | -------------------------------------------- |
| Synchronous           | Bounded delay, pauses, drift         | Unrealistic                                  |
| Partially synchronous | Usually bounded, sometimes unbounded | Best match for real systems; design for this |
| Asynchronous          | No timing assumptions, no clocks     | Very restrictive; few algorithms possible    |

Node failure models:

| Model                   | Assumption                                                                                                                                     |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Crash-stop              | A failed node never returns                                                                                                                    |
| Crash-recovery          | Node may restart; stable storage survives, memory lost. Most useful default                                                                    |
| Degraded / gray failure | Node is slow or partly broken (one bad NIC, degraded disk, throttled CPU). Often worse than a clean crash; a limping node passes health checks |
| Byzantine               | Arbitrary behavior                                                                                                                             |

- Even crash-recovery assumes stable storage is stable. Real disks lose or corrupt data; firmware lies about flushes. An algorithm's guarantees only hold within its model.

## Safety and liveness

- **Safety**: nothing bad happens (uniqueness, monotonic tokens, no split brain). A violation happens at an identifiable moment and cannot be undone.
- **Liveness**: something good eventually happens (a request eventually gets a reply, availability). Usually phrased with "eventually".
- Rule: safety must hold in every execution, even if all nodes crash or the network is partitioned forever. Liveness may be conditional (only when a majority is up and the network heals).

## Testing distributed behavior

| Technique                                                | Tests                                                     | Strength                                                  | Weakness                                       |
| -------------------------------------------------------- | --------------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------- |
| Model checking / specification languages                 | A model of the algorithm                                  | Exhaustive within small bounds; finds design bugs         | Model may drift from code                      |
| Fault injection (chaos testing, network partition tools) | Real system in real environment                           | Finds real-world integration bugs                         | Failures hard to reproduce                     |
| Deterministic simulation testing (DST)                   | Real code with network, disk, clock, and scheduler mocked | Explores many interleavings fast; failures replay exactly | Every nondeterminism source must be controlled |

- DST makes code deterministic at one of three levels: application (event-loop architecture with injectable I/O), runtime (single-threaded deterministic async runtime), or machine (deterministic hypervisor).
- Residual nondeterminism to remove: hash-map iteration order, random seeds, thread scheduling, resource-limit failures.
- Determinism is a recurring design lever: event replay, durable workflow engines, state machine replication.

## Review checklist

- What does the code do when a remote call times out: is the outcome treated as unknown, and is the retry idempotent?
- How was each timeout chosen? Is it measured or adaptive? What happens on a false positive (double execution, cascading failover)?
- Does any correctness decision depend on a wall-clock comparison across nodes (LWW, expiry, ordering)? Could a logical clock or a fencing token replace it?
- Are durations measured with a monotonic clock?
- Is clock offset monitored, and do drifting nodes get removed?
- Is there any check-then-act around a lease or lock? What if the process pauses for a minute between check and act?
- Does the protected resource verify fencing tokens or conditional versions on every write?
- Who decides a node is dead: the node, a peer, or a quorum? Can two nodes both believe they are leader?
- Which system model does the algorithm assume (timing, crash-recovery, storage)? Does the deployment match it?
- Are safety properties preserved during partitions and total restarts, with only liveness lost?
- Is there a test strategy for partitions, pauses, and clock skew (fault injection or DST), not only happy paths?
- Are gray failures (slow, partly working nodes) detected, or do they pass health checks?
