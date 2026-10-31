# Transactions

Covers DDIA 2nd ed., Chapter 8 (Transactions).

## Why transactions, and when to skip them

- A transaction groups reads and writes into one unit that either commits fully or aborts fully. Its value: the application may retry an aborted unit without reasoning about half-applied state.
- Transactions are a design choice, not a law. Dropping them is fine when the workload is single-object or when you accept weaker guarantees for availability or speed. Make that choice explicit; do not inherit it by accident from a storage engine default.
- Rule: if code updates more than one row, document, index, or table that must stay in step (foreign keys, denormalized counters, secondary indexes kept by hand), you need multi-object atomicity and isolation, or a documented compensation plan.

## ACID, decoded

| Letter      | What it really guarantees                                    | Who owns it                 | Pitfall                                                                                 |
| ----------- | ------------------------------------------------------------ | --------------------------- | --------------------------------------------------------------------------------------- |
| Atomicity   | All-or-nothing on fault; abort discards partial writes       | Database                    | Not about concurrency; read it as "abortability"                                        |
| Consistency | Application invariants hold before and after                 | Application                 | The database only checks the constraints you declared                                   |
| Isolation   | Concurrent transactions do not see each other's partial work | Database, at a chosen level | Default level is almost never serializable                                              |
| Durability  | Committed data survives a crash                              | Database plus hardware      | Disk firmware bugs, fsync lies, corruption, correlated failures, async replication loss |

- Durability is probabilistic. Combine disk writes, replication, and backups. Ask what the write acknowledgement actually waited for.
- "Consistency" is overloaded: replica convergence, linearizability, CAP, and ACID invariants are four different ideas. Ask which one is meant.

## Single-object vs multi-object

- Storage engines nearly always give atomicity and isolation for a single object (via log and per-object lock). Atomic increment and compare-and-set are single-object ops; they are not full transactions.
- Multi-object operations need a transaction boundary. Without one: indexes drift from data, denormalized counts drift from rows, related documents disagree.

## Aborts and retries

- Retrying an aborted transaction is the point of having them, but retry is not free:
  - The commit may have succeeded and only the ack was lost. Retry then duplicates the effect unless the operation is idempotent (dedup key).
  - If abort is due to overload, retries amplify load. Use backoff and a retry cap.
  - Only retry transient errors (deadlock, serialization failure, timeout). Do not retry constraint violations.
  - Side effects outside the database (emails, HTTP calls) are not rolled back. Defer them until after commit, or use an outbox.
- Many ORMs do not retry aborted transactions for you. Check.

## Weak isolation levels: the anomalies

Definitions (my phrasing):

- **Dirty read**: you see another transaction's write before it commits.
- **Dirty write**: you overwrite another transaction's uncommitted write.
- **Read skew (non-repeatable read)**: one transaction reads some rows before and others after a concurrent commit, so totals or invariants look broken.
- **Lost update**: two read-modify-write cycles race; one overwrites the other's result.
- **Write skew**: two transactions read the same set, each decides based on what it read, and each writes a different object; together they break an invariant that neither broke alone.
- **Phantom**: a concurrent write adds or removes rows that match a predicate another transaction already queried.

| Level                                  | Dirty read | Dirty write | Read skew | Lost update                       | Write skew | Phantom                                                    |
| -------------------------------------- | ---------- | ----------- | --------- | --------------------------------- | ---------- | ---------------------------------------------------------- |
| Read uncommitted                       | possible   | prevented   | possible  | possible                          | possible   | possible                                                   |
| Read committed                         | prevented  | prevented   | possible  | possible                          | possible   | possible                                                   |
| Snapshot isolation / "repeatable read" | prevented  | prevented   | prevented | some DBs detect it, others do not | possible   | read-only phantoms prevented; write-skew phantoms possible |
| Serializable                           | prevented  | prevented   | prevented | prevented                         | prevented  | prevented                                                  |

- Level names lie. "Repeatable read" means snapshot isolation in some engines and something else in others; "serializable" in some older engines is really snapshot isolation. Test the actual engine behavior, do not trust the label.

## Read committed

- Implementation: row locks for writes held to commit; for reads, return the last committed value (keep old and new versions) rather than taking read locks.
- Adequate for: simple single-row CRUD. Not adequate for: backups, analytics scans, integrity checks, any multi-read decision.

## Snapshot isolation (MVCC)

- Each transaction reads from a consistent snapshot as of its start. Writers do not block readers; readers do not block writers.
- Implementation: keep multiple versions tagged with creator and deleter transaction IDs; a version is visible if its creator committed before the reader started and its deleter did not.
- Indexes point to all versions and filter by visibility, or use copy-on-write (append-only B-trees) so each root is a snapshot.
- Use for: long read-only queries, backups, consistency checks, reports.
- Caveat: snapshot isolation alone does not stop write skew. Garbage collection of old versions is held back by long-running transactions.

## Fixing lost updates in application code

| Technique           | How                                                                           | Use when                                 | Caveat                                                                                |
| ------------------- | ----------------------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------- |
| Atomic write op     | `UPDATE ... SET n = n + 1` or document-level atomic ops                       | Change expressible as a single statement | ORMs often generate read-then-write instead; check emitted SQL                        |
| Explicit lock       | `SELECT ... FOR UPDATE` then modify                                           | Logic too complex for one statement      | Easy to forget one code path; deadlock risk                                           |
| Automatic detection | DB aborts the second writer under snapshot isolation                          | Engine supports it                       | Not all engines do; must retry                                                        |
| Compare-and-set     | `UPDATE ... WHERE value = old_value` (or version column); check rows affected | No transactions, or optimistic style     | If the WHERE reads from an old snapshot, it may not protect you                       |
| Conflict merge      | Commutative ops or CRDT-style merge; keep siblings                            | Multi-leader or leaderless replication   | Locks and CAS assume a single up-to-date copy; last-write-wins silently loses updates |

## Write skew and phantoms

- Pattern: (1) query rows matching a condition, (2) decide in application code, (3) write. Step 3 changes the answer to step 1. Typical cases: on-call minimum staffing, double-booking a room or seat, unique username claim, double-spend of a balance, two players moving to the same square.
- When step 1 returns rows, `SELECT ... FOR UPDATE` on those rows can fix it.
- When step 1 checks for absence (no booking exists, name not taken), there is nothing to lock. That is a phantom; row locks cannot help.

Fixes, in preference order:

1. **Serializable isolation.** The cleanest fix.
2. **Database constraint.** Unique index, exclusion constraint for overlapping ranges, check constraint. Prefer whenever expressible.
3. **Materialize the conflict.** Pre-create rows that stand for the thing being contended (one row per room per time slot), then lock those rows. Ugly; leaks concurrency control into the data model. Last resort.
4. Triggers or materialized aggregates, engine-specific.

## Serializability: three implementations

| Approach                              | Mechanism                                                                                                 | Strengths                                                                      | Weaknesses                                                                                          | Pick when                                                               |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Actual serial execution               | One thread runs whole transactions in order, data in memory, transactions submitted as stored procedures  | Simple, no lock overhead, deterministic                                        | Throughput capped at one core per shard; any slow transaction stalls all; cross-shard txns are slow | Short transactions, small active dataset in RAM, writes shard cleanly   |
| Two-phase locking (2PL)               | Shared locks for reads, exclusive for writes, held to commit; predicate or index-range locks for phantoms | Pessimistic, well understood, prevents all anomalies                           | Readers block writers and vice versa; deadlocks; unstable tail latency; one slow txn blocks many    | Contention high and aborts expensive; legacy                            |
| Serializable snapshot isolation (SSI) | Snapshot isolation plus tracking of reads; abort at commit if a read premise became stale                 | Readers do not block writers; good read-heavy performance; works across shards | Aborts under high contention; long read-write txns abort more                                       | Default choice for new serializable systems when contention is moderate |

Notes:

- Serial execution requires no interactive multi-round-trip transactions: the whole transaction is shipped as code. Stored procedures must be deterministic if replicated by replaying them; version them and deploy them like code.
- 2PL index-range locks approximate predicate locks by locking a broader key range; with no usable index the whole table is locked.
- SSI detects two cases: (a) reading an MVCC version whose newer uncommitted write was ignored and then committed; (b) writing data another transaction has read. Keep read-write transactions short. Read-only transactions under SSI do not need to abort.
- Optimistic control loses under heavy contention (abort storms); pessimistic loses under low contention (needless waiting). Commutative atomic ops reduce contention for both.

## Distributed transactions and two-phase commit (2PC)

- 2PC: a coordinator asks every participant to prepare; a participant that votes yes promises to commit if told, even after crash. The coordinator writes its decision to its own log (commit point), then tells everyone. Both promises are irrevocable.
- Not to be confused with 2PL (locking). Different thing.

Limits:

- **Blocking**: if the coordinator dies after prepare, participants are "in doubt" and must hold locks until the coordinator recovers. Rows stay locked; other transactions stall.
- **Orphaned in-doubt transactions** (lost coordinator log) need a human to resolve, or a heuristic decision that breaks atomicity.
- Coordinator is a single point of failure unless replicated.
- Latency: extra round trips and forced disk writes.
- Three-phase commit assumes bounded delay; not safe on real networks.

| Variant                                                                   | Example category                               | Verdict                                                                                                                                                                                        |
| ------------------------------------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Heterogeneous (XA across a database and a message broker, or two vendors) | XA                                             | Lowest common denominator; no deadlock detection across systems; no SSI across systems; coordinator often a library in the stateless app server, which breaks statelessness. Avoid if possible |
| Database-internal (all participants run the same software)                | NewSQL databases, broker-internal transactions | Viable: replicated coordinator with auto failover, direct coordinator-shard links, replicated shards, integrated concurrency control. Snapshot isolation or SSI across shards possible         |

## Exactly-once without distributed transactions

- Goal: a message's effect lands once even with crashes and redelivery.
- Recipe using only database-local transactions:
  1. Give each message a unique ID; keep a processed-IDs table with a unique constraint.
  2. In one DB transaction: check or insert the ID, do the writes, commit.
  3. Acknowledge to the broker only after commit. Delete the ID later, optionally.
- Crash before commit: retried. Crash after commit before ack: retry sees the ID and drops it. Concurrent duplicate: the unique constraint rejects one.
- Rule: prefer idempotency keys within one database over cross-system atomic commit.

## Review checklist

- Which isolation level does the engine actually run at by default, and what do its names mean in this engine?
- Is there any read-modify-write in application code? Is it atomic, locked, CAS-guarded, or exposed to lost updates?
- Does the ORM emit read-then-write where an atomic update was intended?
- Is there any check-then-act on a predicate (availability, uniqueness, balance, quota)? What stops write skew or phantoms: serializable isolation, a constraint, or materialized rows?
- Can a constraint (unique, exclusion, check) replace application-level checking?
- Are retries limited to transient errors, backed off, and safe given a possibly committed first attempt (idempotency key)?
- Are external side effects deferred until after commit?
- Are long-running read-write transactions avoided (SSI abort rate, MVCC garbage, 2PL blocking)?
- Under multi-leader or leaderless replication, is last-write-wins silently dropping updates?
- Does the design use cross-system 2PC/XA? What happens to locks if the coordinator dies mid-commit? Could a dedup-key pattern replace it?
- What does a "committed" ack wait for: local fsync, replica ack, or neither?
