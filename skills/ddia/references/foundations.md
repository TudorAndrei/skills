# Foundations: Architecture Trade-Offs and Nonfunctional Requirements

Covers DDIA 2nd ed. Chapter 1 (trade-offs in data systems architecture) and Chapter 2 (nonfunctional requirements).

## Operating stance

- Treat every architecture choice as a trade-off. Reject claims that one tool or pattern is "best" without naming the workload, scale, team, and cost it is best for.
- Make the hidden requirements explicit before you compare options. Different teams on the same dataset often want contradictory things.
- Prefer the simplest design that meets stated requirements now and within the next order of magnitude of growth.

## Operational (OLTP) vs analytical (OLAP) workloads

Classify each workload before you choose storage, schema, or hosting.

| Dimension    | Operational / OLTP                                | Analytical / OLAP                          |
| ------------ | ------------------------------------------------- | ------------------------------------------ |
| Reads        | Fetch few records by key (point lookups)          | Scan many rows, compute aggregates         |
| Writes       | Per-record create/update/delete from user actions | Bulk loads (ETL) or event streams          |
| Query shape  | Fixed set, coded into the app                     | Ad hoc, exploratory, tool-generated        |
| Query volume | Very many cheap queries                           | Few heavy queries                          |
| Data meaning | Current state                                     | History of what happened                   |
| Typical size | GB to TB                                          | TB to PB                                   |
| Who queries  | End users via app; authz checks                   | Analysts, data scientists; fraud detection |

Rules:

- Do not let end users or analysts run arbitrary SQL against an OLTP database: it bypasses access control and lets one expensive query degrade everyone.
- Run analytics on a separate copy when: data is spread across many operational stores (silos), OLTP schema is a poor fit for aggregation, analytical load would hurt OLTP latency, or OLTP sits in a restricted network.
- Product/real-time analytics (aggregation embedded in a user-facing feature, e.g. Pinot, Druid, ClickHouse) is a third category: real-time ingest plus low-latency aggregate queries. Traditional OLAP favors batch ingest and throughput.
- HTAP (one system for both) is a fit only when one application needs both low-latency row updates and large scans on the same data (e.g. fraud checks). It does not replace a central warehouse; internally it usually still has two engines.

## Warehouse, lake, and pipelines

| Store          | Contents                                               | Schema                                         | Main consumers                            | Notes                                                                         |
| -------------- | ------------------------------------------------------ | ---------------------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------- |
| Data warehouse | Cleaned copy of many OLTP sources                      | Relational, analysis-oriented (star/snowflake) | BI analysts via SQL                       | Usually one per enterprise so cross-source joins work                         |
| Data lake      | Raw files of any kind (records, text, images, vectors) | None imposed; files in e.g. Avro/Parquet       | Data scientists, ML, downstream pipelines | Cheaper; uses object storage; consumers transform raw data to their own needs |
| Stream         | Events as they happen                                  | Per-event                                      | Low-latency analytics, fraud blocking     | Seconds-level reaction instead of periodic batch reruns                       |

- ETL = extract, transform, then load. ELT = load raw, transform inside the warehouse. Choose ELT when transformation needs the warehouse's compute or when several consumers want different shapes.
- Keep raw data available when feasible: each consumer can re-derive its own view, and you can fix transform bugs by reprocessing.
- Reverse ETL: pushing analytical outputs (e.g. trained models, scores) back into operational systems. Treat that output as derived data with its own freshness and correctness contract.
- SaaS sources only expose APIs; plan for connector services and API rate/shape limits.

## Systems of record vs derived data

- System of record (source of truth): where a fact is first written, stored once, usually normalized. On disagreement, it wins.
- Derived data: anything you can rebuild from another source: caches, indexes, materialized views, denormalized copies, transformed datasets, ML models.
- The label depends on how you use a tool, not on the tool. Write down, for each store, which role it plays and what it derives from.
- Every derived store needs an explicit update path from its source. Most databases assume they are alone and give no help here; plan the pipeline.
- Failure mode: two stores both treated as authoritative for the same fact. Result: silent divergence with no rule for which is right.

## Cloud vs self-hosting

Decide build vs buy first: keep in-house what is core or differentiating; outsource commodity work. Hosting options form a spectrum: bespoke self-run, off-the-shelf self-hosted (on-prem or IaaS VMs), managed service, SaaS.

| Factor                     | Favors cloud service                                       | Favors self-hosting                         |
| -------------------------- | ---------------------------------------------------------- | ------------------------------------------- |
| Team skill with the system | Low; learning to operate it is costly                      | High; already operated in production        |
| Load shape                 | Spiky or bursty (e.g. interactive analytics on large data) | Predictable, steady                         |
| Tuning needs               | Generic workload                                           | Workload-specific config, custom features   |
| Debuggability              | Acceptable to lack OS metrics and server logs              | Need full internals to diagnose             |
| Vendor risk                | Compatible alternatives exist                              | No standard API; lock-in is costly          |
| Control                    | Can wait out vendor outages                                | Need hard latency control (e.g. trading)    |
| Compliance / jurisdiction  | Provider trusted with data; no sanctions exposure          | Data must stay under own control or country |

Cloud-native design points:

- Cloud-native systems build on lower-level managed services (object storage, specialized log/storage services) instead of emulating a machine. They tend to gain faster recovery, elastic compute, and larger datasets.
- Separation of storage and compute: durable data lives in a storage service; compute nodes are replaceable and treat local disk as an ephemeral cache.
- Virtual block devices (network-attached disks) let legacy software run in cloud but add overhead and make every I/O a network call, so the app becomes sensitive to network glitches.
- Object storage suits large blobs (hundreds of KB to GB). Databases on object storage keep small values elsewhere and batch many values into large objects.
- Multitenancy improves utilization but needs isolation for performance and security between tenants.
- Higher-level managed services are easier when your need matches their design; compose lower-level services only when nothing fits.

Operations still exist in the cloud: capacity planning becomes cost planning; you must know quotas and limits before hitting them; integration between services, security patching of your code and libraries, and incident diagnosis remain your job.

## Distributed vs single-node

Valid reasons to distribute: inherent multi-device use, data in one service processed in another, fault tolerance, data or compute beyond one machine, geographic latency, elastic cost, specialized hardware per role, data residency law, running work where/when energy is cheap.

Costs of distribution:

- Any network call can time out with unknown outcome; blind retry may be unsafe (need idempotency).
- Remote calls are orders of magnitude slower than in-process calls; moving computation to the data can beat moving data.
- More nodes can be slower than one well-written single-threaded program.
- Diagnosis needs observability: metrics plus queryable per-event traces (e.g. OpenTelemetry-style tracing).
- Per-service databases move cross-service consistency into application code; distributed transactions are rarely available or welcome there.

Rule: stay single-node until a concrete reason above applies. Modern hardware plus embedded engines (e.g. SQLite, DuckDB) covers many workloads.

### Microservices and serverless

- Microservices: one purpose, one API, one owning team per service, own private database. Sharing a database makes its schema part of the API and couples performance.
- They solve an organizational problem (teams shipping independently). In a small org they are mostly overhead; start with the simplest deployable unit.
- Costs: integration testing needs dependent services, per-service deploy/monitor/alert infra, API evolution can break clients late. Use schema/API description tooling (OpenAPI, gRPC).
- Serverless/FaaS: pay per execution, autoscaled; constraints are execution time limits, restricted runtimes, cold starts. "Serverless" on data products usually just means usage-billed autoscaling.

### Cloud vs HPC

HPC checkpoints and restarts the whole job on node failure, trusts all nodes, and uses special topologies. Online services must stay up through failures and assume untrusted tenants. Do not borrow HPC failure handling for always-on services.

## Law, privacy, and data minimization

- Privacy law (e.g. GDPR, CCPA) and AI rules shape design: purpose limitation, retention limits, right to erasure.
- Erasure conflicts with append-only logs, immutable files, and derived datasets including ML training data. Design a deletion path through every derived store before launch.
- Cost of keeping data includes breach liability, fines, legal compulsion, and real harm to users when data reveals criminalized behavior (e.g. location history).
- Default to data minimization: do not collect or retain data speculatively.
- Expect compliance audits (PCI for payments, SOC 2 for vendors).

## Performance: response time and throughput

- Throughput: work per second; sets hardware and cost. Response time: what the client waits; what users feel.
- Response time = service time + queueing delays + network latency. Measure it at the client, since queueing is invisible to the server's own service-time metric.
- Response time rises sharply as throughput nears capacity because of queueing. Head-of-line blocking: a few slow requests stall fast ones behind them.
- Overload failure mode: timeouts trigger retries, retries add load, system stays overloaded after the trigger is gone (metastable failure, retry storm). Countermeasures: client exponential backoff with jitter, circuit breakers or token buckets, server load shedding, backpressure, sensible queueing and load balancing.

### Percentiles

- Treat response time as a distribution. Mean is useful only for throughput estimates.
- Use p50 for typical experience; p95/p99/p999 for tail latency. Tail requests often belong to the heaviest, most valuable users.
- Tail latency amplification: when one user request fans out to N backend calls, the slowest call sets the total. Backend tails matter more the larger the fan-out.
- Very high percentiles (e.g. p9999) are dominated by random events and often not worth the cost.
- Never average percentiles across time windows or hosts. Merge histograms instead (HdrHistogram, t-digest, DDSketch style sketches).
- SLO = target (e.g. p50 and p99 bounds plus success rate). SLA = contract with consequences if the SLO is missed.

## Read-time vs write-time work (fan-out)

- Materialization: precompute query results on write (a materialized view / cache) so reads are cheap. Trade: more write work and derived data to keep correct.
- Fan-out factor: how many downstream writes or calls one request causes. Size it from the load distribution, not the mean.
- Skewed keys break the uniform plan: for high-fan-out producers, skip precomputation and merge at read time (hybrid). For high-fan-in consumers, sampling may be acceptable if the product allows lossy results.
- Queue fan-out work during spikes; accept delayed delivery while keeping reads fast.

## Reliability

- Fault: one component deviates. Failure: the system as a whole misses its SLO. Goal is fault tolerance, so faults do not become failures.
- Single point of failure (SPOF): a component whose fault causes system failure. Find and list them.
- Tolerance is always bounded: state which faults and how many (e.g. one of three nodes).
- Inject faults deliberately (chaos engineering) to keep recovery paths exercised; poor error handling is a common source of critical bugs.
- Prefer tolerating faults, except where no cure exists (security breaches): there, prevent.

| Fault class                                                                                                                       | Correlation                                          | Typical mitigation                                                                                                                           |
| --------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Hardware (disks, SSD, RAM bit flips, faulty CPU cores, power, whole datacenter)                                                   | Mostly independent, but rack/zone correlations exist | Component redundancy (RAID, dual PSU); software-level replication across machines and availability zones; rolling upgrades                   |
| Software (shared bug, leap-second style triggers, resource exhaustion, slow dependency, emergent interactions, cascading failure) | Highly correlated across nodes running same code     | Question assumptions, test, process isolation, crash-and-restart, avoid retry feedback loops, monitor production                             |
| Human (config changes are a leading outage cause)                                                                                 | Systemic                                             | Tests incl. property-based, fast rollback, gradual rollout, observability, interfaces that make the right action easy, blameless postmortems |

- At scale, hardware faults are routine, not exceptional. Design for machine loss, not machine perfection.
- Treat "human error" as a symptom of the sociotechnical system. Distrust simplistic root causes in either direction.
- Data loss or corruption is usually far worse than short downtime. Weight durability and backup-restore drills accordingly.
- If you cut reliability to ship faster, record that decision and its risk explicitly.

## Scalability

- "Scalable" is not a property; ask: if load grows along dimension X, what are the options, what resources do we add, and when do we hit the current limit?
- First describe load with the right parameters: requests/s, data/day, peak concurrency, read/write ratio, cache hit rate, items per entity, and the shape of the distribution (mean vs extreme cases).
- Two views: hold resources fixed and watch performance degrade, or hold performance fixed and measure resources needed.
- Linear scalability (2x resources for 2x load) is good; worse than linear is common.
- Do not build for hypothetical scale at an early-stage product; it wastes effort and can lock in an inflexible design. Expect to re-architect per order-of-magnitude growth; plan at most one order ahead.

| Architecture                | How it scales                                         | Limits                                                     |
| --------------------------- | ----------------------------------------------------- | ---------------------------------------------------------- |
| Shared-memory (vertical)    | Bigger machine, more cores/RAM                        | Cost superlinear; bottlenecks prevent 2x; one fault domain |
| Shared-disk                 | Many compute nodes, shared NAS/SAN                    | Lock contention and coordination overhead                  |
| Shared-nothing (horizontal) | Add independent nodes                                 | Needs sharding; full distributed-systems complexity        |
| Cloud disaggregated storage | Many compute nodes over a DB-specific storage service | Depends on provider; avoids classic shared-disk limits     |

Principles: split into parts that run mostly independently (services, shards, streams); do not add complexity before it is needed; manual scaling may surprise less than autoscaling when load is predictable; fewer services beats more.

## Maintainability

Most software cost is maintenance. Three levers:

- Operability: monitoring and observability hooks; no dependence on any single machine; clear operational model ("doing X causes Y"); good defaults that admins can override; self-healing with manual override; predictable behavior. More automation is not always better: automated failures are harder to debug and leftover cases need skilled operators.
- Simplicity: remove accidental complexity; use abstractions that hide detail behind a small, reusable interface (transactions, indexes, logs). Watch for "big ball of mud" signals: hidden assumptions, surprising interactions.
- Evolvability: loose coupling, simple parts, and reversibility. Treat irreversible steps (e.g. one-way database migration) as high risk; keep a rollback path.

## Review checklist

- Is each workload labeled OLTP, OLAP, or real-time analytics, and is storage chosen to match?
- Are analytical queries isolated from the operational database?
- For each store: system of record or derived? What derives from what, and how is derived data updated and rebuilt?
- Is the cloud vs self-host choice justified by skills, load shape, control, lock-in, and compliance, not by habit?
- Is distribution justified by a concrete reason, or would one node suffice?
- Do microservices map to real team boundaries? Does any service share another's database?
- Are load parameters stated, including skew and peaks, not just averages?
- Are latency targets expressed as client-side percentiles with SLOs? Are percentiles aggregated by histogram merge?
- What happens at overload: backoff, circuit breaking, load shedding, backpressure?
- Which faults are tolerated, how many, and where are the SPOFs? Is fault injection or restore testing done?
- Is there a plan for correlated software faults and bad config pushes (gradual rollout, rollback)?
- Can personal data be erased from logs, backups, and derived datasets? Is any data collected without a stated purpose?
- Which steps are irreversible, and what is the rollback path?
