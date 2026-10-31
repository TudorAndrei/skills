# Encoding and Evolution

Covers DDIA 2nd ed., Chapter 5 (Encoding and Evolution).

## Compatibility directions

- **Backward compatible**: new code reads data that old code wrote. Usually easy: the new code knows the old format.
- **Forward compatible**: old code reads data that new code wrote. Harder: old code must ignore what it does not understand.
- During a rolling upgrade, a staged client rollout, or a mixed-version cluster, old and new code run at the same time. Data and messages flow both ways. Assume you need **both** directions unless you can prove an ordering.
- Name the direction of every change in a review: "new reader, old data" or "old reader, new data".

Rules:

- Every persisted or transmitted format is a contract with versions of code that you do not control (old replicas, mobile clients, other teams, archived files).
- Never ship a schema change and the code that depends on it in one step if any old reader can see the new data. Deploy readers that tolerate the new shape first, then writers.

## Language-native serialization (Java Serializable, pickle, Marshal, etc.)

Do not use for anything stored or sent between services.

- Ties the data to one language runtime.
- Decoding can instantiate arbitrary classes: a remote code execution risk on untrusted input.
- Versioning is an afterthought; compatibility in both directions is usually weak.
- Often slow and bulky.
  Acceptable only for transient, same-process, same-version use.

## Textual formats: JSON, XML, CSV

Strengths: human readable, universal, good for data exchange between organizations where agreeing on anything is the hard part.

Failure modes to check:

| Problem           | Effect                                                                                                           | Mitigation                                                              |
| ----------------- | ---------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Number ambiguity  | JSON does not separate int from float; integers above 2^53 lose precision in IEEE-754 parsers (e.g., 64-bit IDs) | Send large IDs as strings as well as or instead of numbers              |
| No binary strings | Base64 inflates size by about a third, needs out-of-band knowledge                                               | Document which fields are Base64, or use a binary format                |
| XML/CSV typing    | XML cannot tell a number from a digit string without a schema; CSV has no schema at all and loose escaping rules | Use a schema; use a strict CSV parser                                   |
| Schema optional   | Each consumer hardcodes its own interpretation                                                                   | Adopt JSON Schema / XML Schema, or move to a schema-based binary format |

### JSON Schema

- Widely used (OpenAPI, schema registries, database validators). Adds value constraints (ranges, patterns) on top of types.
- Default content model is **open** (`additionalProperties` true): unknown fields are allowed. A schema then lists what is forbidden, not what is allowed.
- Closed models block forward compatibility: an old validator rejects a new field.
- Conditional logic, remote references, and pattern properties make schemas hard to reason about and hard to evolve safely. Prefer simple schemas if evolution matters.

### Binary JSON variants (MessagePack, BSON, etc.)

Small gain only: field names are still in every record. Rarely worth losing readability.

## Schema-based binary formats

### Protocol Buffers (and Thrift, which works the same way)

- Each field has a numeric **tag**. The encoding stores tags, not names. Field names can change freely; tags can never change.
- Unknown tags are skipped by old readers (the wire type tells the parser how many bytes to skip). This gives forward compatibility.

Evolution rules:

| Change                   | Safe?  | Condition                                                                       |
| ------------------------ | ------ | ------------------------------------------------------------------------------- |
| Add field                | Yes    | New tag number; new code must handle absence (default) for old data             |
| Remove field             | Yes    | Never reuse the tag; mark it reserved                                           |
| Rename field             | Yes    | Tag unchanged                                                                   |
| Change tag number        | No     | Breaks all existing data                                                        |
| Change type              | Risky  | Widening (e.g., 32 to 64-bit) can truncate in old readers                       |
| Make field required      | No     | Old data lacks it (proto3 has no required)                                      |
| Single value to repeated | Partly | Repeated is a field appearing many times; old readers see only the last element |

### Avro

- No tags in the schema or the data. Bytes are a plain concatenation of values; decoding is only possible with the exact **writer's schema**.
- Decoder resolves writer's schema against **reader's schema** by field name. Missing in writer: reader's default used. Extra in writer: ignored.
- Forward compatibility = writer's schema newer than reader's. Backward = writer's schema older.

Evolution rules:

| Change                       | Backward               | Forward | Note                                    |
| ---------------------------- | ---------------------- | ------- | --------------------------------------- |
| Add field with default       | Yes                    | Yes     | The only safe way to add                |
| Add field without default    | No                     | Yes     | New readers cannot fill it for old data |
| Remove field with default    | Yes                    | Yes     |                                         |
| Remove field without default | Yes                    | No      | Old readers cannot fill it              |
| Rename via reader alias      | Yes                    | No      |                                         |
| Add a union branch           | Yes                    | No      |                                         |
| Type change                  | If Avro can promote it |         |                                         |

- Null is not a universal default. A nullable field must be a union with null, and null can be the default only if it is the first branch.

How the reader gets the writer's schema (must be designed in):

| Context                                 | Mechanism                                                         |
| --------------------------------------- | ----------------------------------------------------------------- |
| Large file of uniform records           | Schema once in the file header (object container file)            |
| Database with records written over time | Version number or schema hash per record + schema registry lookup |
| Long-lived connection                   | Negotiate schema version at connection setup                      |

- When to prefer Avro: schemas generated from another schema (e.g., dumping a relational DB). No tags to allocate by hand, so regenerating on every schema change is safe. With Protocol Buffers, a generator must never reuse tags.

### Why schemas pay off

- More compact than any self-describing format (no field names in data).
- Schema is documentation that cannot go stale, because decoding needs it.
- A registry of all schema versions lets CI check compatibility before deploy.
- Codegen gives compile-time type checks in static languages. Avro also works without codegen for dynamic languages.

## Format selection table

| Need                                               | Prefer                                                       |
| -------------------------------------------------- | ------------------------------------------------------------ |
| Public API, external partners, browsers            | JSON (+ OpenAPI / JSON Schema)                               |
| Internal RPC between services you own              | Protocol Buffers (gRPC)                                      |
| Bulk files, data lake, DB dumps, generated schemas | Avro (or columnar formats for analytics)                     |
| Messages on a broker with many consumers           | Avro or Protobuf + schema registry with compatibility checks |
| In-process cache of same-version objects           | Anything, including native                                   |
| Untrusted input                                    | Never native serialization                                   |

## Dataflow through databases

- The process that writes a value and the process that later reads it can be different code versions. Writing to a DB is a message to your future self: needs backward compatibility. During rolling deploys, old code also reads rows written by new code: needs forward compatibility.
- **Data outlives code.** Old rows remain in old encoding until rewritten. Rewriting (migrating) a large table is expensive; most databases allow cheap changes such as adding a nullable column and fill in null when reading old rows.
- **Lost-update trap with unknown fields**: old code reads a record that has a new field, decodes it into its model object (dropping the unknown field), and writes it back. The new field is silently deleted. Rule: decoders and ORMs must keep unknown fields round-trip, or old code must not rewrite whole records.
- Archive snapshots and backups: encode the whole dump with the latest schema at dump time; a self-describing, immutable format (e.g., Avro container files, Parquet) suits it.

## Dataflow through services: REST and RPC

- Service = an API that encapsulates its data and limits what clients can do. Goal: deploy and evolve each service independently.
- REST/HTTP with JSON: good for external and browser clients, strong tooling, debuggable. Describe with OpenAPI.
- RPC frameworks (gRPC etc.) try to make a remote call look like a local call. This abstraction leaks:

| Local call                   | Network call                                                              |
| ---------------------------- | ------------------------------------------------------------------------- |
| Succeeds or throws           | Can time out with no result; you do not know whether it executed          |
| Retry is harmless            | Retry may execute the action twice: need idempotency keys / deduplication |
| Latency is stable            | Latency varies wildly                                                     |
| Pass references and pointers | Must encode everything into bytes; large objects are costly               |
| Same language types          | Type translation between languages (e.g., large ints in JS)               |

Rules:

- Treat every remote call as fallible and possibly duplicated. Make mutating endpoints idempotent.
- Be explicit that a call is remote. Do not hide it behind an interface that looks local.

Compatibility for services:

- You can usually assume servers deploy before clients. Then you need **backward compatibility on requests** and **forward compatibility on responses**.
- Adding optional request parameters and adding response fields is normally safe. Removing or renaming is not.
- Across organizational boundaries you cannot force clients to upgrade; compatibility must last for a long time. A breaking change means running several API versions side by side.
- Versioning options: version in URL path, version in Accept header, or per-API-key pinned version stored on the server. Pick one and document it.

Load balancing and discovery (category level): hardware or software load balancers, service discovery registries (clients find instances directly, need health checks and fresh membership), service meshes (sidecar proxies with TLS, observability, routing). More moving parts give more control and more operational cost.

## Durable execution and workflows

- A **workflow** is a graph of tasks across services (e.g., fraud check, card debit, bank deposit). A workflow engine has an orchestrator (schedules) and executors (run tasks).
- Categories: ETL orchestrators, BPMN/visual engines, and **durable execution** frameworks (e.g., Temporal, Restate).
- Durable execution logs every RPC result and state change to durable storage. On retry after failure, it replays the code and returns logged results instead of repeating completed calls. Goal: effectively exactly-once workflows without a cross-service transaction.

Caveats (each one is a review item):

- External services still need **idempotent APIs with unique request IDs**; the framework cannot dedupe a call whose result it did not log.
- Replay requires the code to make the **same calls in the same order**. Reordering or inserting calls in a running workflow's code breaks replay. Deploy changed workflow code as a new version; let in-flight runs finish on the old version.
- Code must be **deterministic**: no direct random numbers, wall clock, or unordered iteration. Use the framework's deterministic replacements; use its static checks if it has them.

## Event-driven architectures and message brokers

Broker vs direct RPC:

- Buffers when consumer is down or slow; redelivers to crashed consumers; removes need for service discovery; supports fan-out; decouples producer from consumer identity.
- Asynchronous by default: the sender does not wait. Request/response over a broker needs a reply channel and correlation IDs.

Patterns: **queue** (each message goes to one consumer of a group) vs **topic / pub-sub** (each subscriber gets every message).

Rules:

- Brokers do not enforce a data model. Use an explicit encoding plus a schema registry with compatibility checks; describe channels with AsyncAPI where useful.
- Check retention: many brokers delete messages after consumption. Event sourcing needs indefinite retention.
- A consumer that republishes to another topic must **preserve unknown fields** (same trap as with databases).

### Distributed actor frameworks (e.g., Akka, Orleans, Erlang/OTP)

- Actors with private state exchange async messages; the framework places actors on nodes and makes location transparent.
- Location transparency fits better than in RPC, because the model already assumes message loss.
- Rolling upgrades still send messages between old and new versions: use an evolvable encoding.

## Review checklist

- For each format in the design: who writes it, who reads it, and can they run different code versions at once? Are both compatibility directions covered?
- Is any native-language serialization used for storage, network, or untrusted input?
- Are 64-bit integers or binary blobs sent through JSON safely?
- Protobuf: are removed tags reserved and never reused? Any required fields or tag changes?
- Avro: does every added or removed field have a default? How does each reader get the writer's schema?
- Is there a schema registry with automated compatibility checks in CI or at publish time?
- Can old code rewrite a record and drop fields it does not know? Do ORMs or consumers preserve unknown fields?
- Do database migrations need a full rewrite, or is the change lazy and cheap (nullable column with default)?
- Is the deploy order (readers first, servers before clients) explicit?
- Are remote calls idempotent, with timeouts and retry policy? Is the remote nature visible in the code?
- What is the API versioning scheme, and how long will old versions be supported?
- For durable workflows: are external calls idempotent with unique IDs, is workflow code deterministic, and is there a plan for versioning workflow code with runs in flight?
- For brokers: queue or topic semantics, retention period, schema registry, and unknown-field preservation on republish?
