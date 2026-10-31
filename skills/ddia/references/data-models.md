# Data Models and Query Languages

Covers DDIA 2nd ed. Chapter 3 (relational, document, graph, event sourcing/CQRS, DataFrames, and their query languages).

## Operating stance

- Pick the data model from the shape of relationships and the dominant access pattern, not from fashion. The model shapes code and how the team thinks about the domain.
- Expect layered models: app objects over a general model (tables, documents, graph) over storage bytes. Each layer should hide the one below with a clean interface.
- Most mainstream databases now span several models (JSON in relational, joins in document stores). Compare what a specific engine does well, not the marketing label.

## Declarative vs imperative querying

- Declarative languages (SQL, Cypher, SPARQL, Datalog) state the result's conditions; the optimizer picks indexes, join order, and parallelism.
- Prefer declarative access when available: shorter code, engine can improve or parallelize without query changes.
- Imperative or pipeline-style APIs (e.g. DataFrame commands, aggregation pipelines) give step control; use them when stepwise exploration or custom transforms dominate.

## Model selection

| Criterion                | Relational                                                         | Document                                         | Graph (property / triple)                                     |
| ------------------------ | ------------------------------------------------------------------ | ------------------------------------------------ | ------------------------------------------------------------- |
| Dominant relationship    | Many-to-one, many-to-many                                          | One-to-many tree, loaded as a whole              | Many-to-many everywhere, multi-hop                            |
| Joins                    | Strong, optimizer-driven                                           | Weak or limited; often done in app               | Traversals are native; variable-length paths                  |
| Schema                   | Enforced on write                                                  | Usually implicit (schema-on-read)                | Flexible; any vertex may link to any vertex                   |
| Locality                 | Spread across tables unless engine supports interleaving           | Whole document stored together                   | Adjacency via edge indexes                                    |
| Referencing nested items | Direct by ID                                                       | Awkward (positional path inside document)        | Direct by vertex ID                                           |
| User-ordered lists       | No standard method (int ordering, linked IDs, fractional indexing) | Natural (JSON array order)                       | Possible via edges, not natural                               |
| Best fit                 | OLTP with shared entities; warehouses                              | Self-contained aggregates, heterogeneous records | Social, network, knowledge, hierarchy-with-varying-depth data |
| Weak spot                | Deep trees need "shredding" into many tables                       | Shared entities; cross-document consistency      | n-ary relationships need an extra vertex; less tooling        |

Decision rules:

- Data is a tree of one-to-few children, usually read whole: document model, or JSON column in relational.
- Children are unbounded (thousands per parent): store them as separate rows/documents, not embedded.
- Entities are shared and referenced from many places: normalize and reference by ID; relational or relational-document hybrid.
- Queries follow a variable number of hops (containment hierarchies, reachability, recommendations): graph model and graph query language.
- Records have many unrelated types, or structure is controlled by an external system: schema-on-read is acceptable.
- All records share one structure: enforce a schema; it documents and protects the data.

## Object-relational mapping (ORM)

- Mismatch between in-memory objects and tables is real; ORMs reduce boilerplate for simple CRUD and can help with caching and migrations.
- ORMs do not remove the need to design the relational schema: analytics and other consumers read the tables directly.
- Generated schemas can be awkward and inefficient; heavy customization cancels the benefit.
- ORMs rarely cover non-relational stores in a heterogeneous estate.
- Failure mode: N+1 queries (one query for a list, then one per item to resolve a reference). Detect by counting queries per request; fix with eager loading or an explicit join.

## Normalization vs denormalization

- Normalized: human-meaningful values stored once, referenced by an opaque ID that never needs to change. Benefits: consistent spelling, no ambiguity, one place to update, localization, richer search semantics.
- Denormalized: the value is copied into each record that uses it.

| Aspect           | Normalized                  | Denormalized                                   |
| ---------------- | --------------------------- | ---------------------------------------------- |
| Writes           | Cheap, one copy             | Must update every copy; more disk              |
| Reads            | Need joins / lookups        | Fewer joins, faster                            |
| Consistency risk | Low                         | Copies can diverge; partial updates on crash   |
| Typical fit      | OLTP, small-to-medium scale | Analytics, read-heavy hot paths at large scale |

Rules:

- Default to normalized at small or moderate scale; joins are affordable and there is nothing to keep in sync.
- Treat every denormalized copy as derived data: name its source and the process that updates it.
- Multi-copy updates need atomic multi-record transactions or a reliable stream process; many document stores lack cross-document atomicity.
- Do not denormalize fast-changing values (counters, profile names, avatars) into precomputed structures. Store IDs and "hydrate" them at read time; that is an app-side join, and it parallelizes well.
- Mix strategies: denormalize what changes rarely and is read often; keep volatile data normalized. Base the choice on change rate and read/write cost, including outliers.
- Claim to reject: "joins prevent scalability". Read-time ID hydration scales because its cost does not depend on fan-out.

## Relationship types

- One-to-many (one-to-few): tree; embed in a document or child table.
- Many-to-one: many records point to one entity (e.g. region); use a reference ID.
- Many-to-many: relational join table; in documents, references by ID in one place plus a secondary index on the nested field.
- Storing the relationship on both sides is denormalization and can diverge. Prefer one side plus secondary indexes so both directions are queryable.
- Check that the engine can index values inside JSON arrays if you rely on that.

## Analytics schemas: star, snowflake, OBT

- Fact table: one row per event (sale, click), usually very large and wide (often 100+ columns); attributes plus foreign keys to dimensions.
- Dimension tables: who, what, where, when, how, why of the event. Date/time is often a dimension too (to attach holidays and similar attributes).
- Star: facts plus flat dimensions. Snowflake: dimensions split into subdimensions (more normalized). Prefer star for analyst usability unless a reason exists.
- One big table (OBT): dimensions folded into the fact table; more storage, sometimes faster queries.
- Denormalization is safe here because facts are historical and rarely updated; OLTP consistency concerns mostly do not apply.
- Multi-item transactions appear as several fact rows sharing keys, not as a modeled entity.

## Schema-on-read vs schema-on-write

| Aspect        | Schema-on-write                                                    | Schema-on-read                                       |
| ------------- | ------------------------------------------------------------------ | ---------------------------------------------------- |
| Analogy       | Static typing                                                      | Dynamic typing                                       |
| Enforced by   | Database at write                                                  | Application code at read                             |
| Format change | Migration (ALTER plus backfill)                                    | Write new shape; readers handle old and new          |
| Cost          | Large backfills rewrite every row; type changes may copy the table | Every reader carries legacy-format handling forever  |
| Good for      | Uniform records                                                    | Heterogeneous types; externally controlled structure |

Rules:

- "Schemaless" is false: readers still assume a structure. Make the implicit schema explicit somewhere (validation, types, docs).
- Adding a nullable column with a default is usually cheap; full-table UPDATEs and type changes are expensive. Use online schema-change tools on large tables.
- Hybrid option: add a nullable column cheaply and fill it lazily at read time.

## Locality

- Document stores keep a record as one contiguous encoded blob (JSON, BSON, XML). Reading the whole thing is one fetch.
- Locality helps only when you need most of the document. The engine typically loads and rewrites the whole document even for tiny changes.
- Rules: keep documents small; avoid frequent small updates to large documents; avoid unbounded growth.
- Relational engines can also provide locality: interleaved child rows (e.g. Spanner), multi-table clusters (e.g. Oracle), column families in wide-column stores (e.g. Bigtable, HBase).

## Query languages for documents

- Range: key-value only, secondary indexes on inner fields, or full languages (aggregation pipelines with join stages; XPath/XQuery for XML; JSONPath-style addressing).
- A JSON pipeline language can match a subset of SQL in expressiveness; syntax is a matter of taste. Check what joins and aggregations the engine actually supports before choosing.

## Graph models

Property graph: vertex = ID, label, properties, in-edges, out-edges. Edge = ID, tail, head, label, properties.

- Any vertex may connect to any other; labels keep many entity types in one clean graph.
- Index both edge endpoints so traversal works forward and backward.
- It is a generalized join table holding many relationship types.
- Edges are binary. Model three-way relationships with an intermediate vertex (or a hypergraph).
- Graphs tolerate irregular data well: differing hierarchy levels per region, varying granularity, new relationship types added without schema change.

Triple store: every fact is (subject, predicate, object). Object is either a literal (acts as a property) or another vertex (acts as an edge). Some engines add a graph ID, transaction ID, or deletion flag per tuple. RDF uses URIs as namespaces so independently produced datasets can merge without name clashes.

Representations: adjacency lists suit traversal; adjacency matrices suit ML/linear algebra.

### Graph query languages

| Language          | Model            | Strength                                          | Note                                                     |
| ----------------- | ---------------- | ------------------------------------------------- | -------------------------------------------------------- |
| Cypher / GQL      | Property graph   | Concise path patterns, variable-length hops       | GQL is the ISO standard based on Cypher                  |
| SPARQL            | RDF triples      | Path patterns; properties and edges share syntax  | Older; Cypher borrowed its patterns                      |
| Datalog           | Relational facts | Composable recursive rules, like functions        | Niche engine support; very expressive                    |
| SQL recursive CTE | Relational       | Works when graph lives in tables                  | Verbose; must handle cycles and traversal order yourself |
| GraphQL           | Any backend      | Client asks for exactly the JSON shape a UI needs | Not a graph DB language; see below                       |

Rules:

- If queries need an unknown number of joins (recursive containment, reachability), a graph language is much simpler than recursive SQL.
- With recursive SQL, guard against cycles and decide breadth- vs depth-first.
- The optimizer may start traversal from either end; give it indexes on lookup properties (e.g. names) so it can anchor on a selective vertex.

## GraphQL

- For OLTP client-to-server fetches; response mirrors the query shape exactly.
- Deliberately restricted because queries come from untrusted clients: no recursion, no arbitrary search unless the server exposes it; only joins declared in the schema.
- Responses intentionally duplicate nested data (e.g. sender info per message) to simplify rendering; storage can stay normalized.
- Costs: resolver layer to internal REST/gRPC services, authorization per field, rate limiting, query-cost control.
- Failure mode: resolvers that fetch per item (N+1) behind a single client query.

## Event sourcing and CQRS

- Event sourcing: the source of truth is an append-only, ordered log of immutable events. CQRS: separate write representation from one or more read-optimized materialized views (projections, read models) derived from it.
- Flow: a command arrives, is validated, and only then becomes an event (fact). Consumers building views must not reject events; the log holds only valid events.
- Name events in past tense; a later change or cancellation is a new event, not an edit.
- Unlike a fact table, events have many types with different fields, and order matters.

Benefits:

- Events record intent, which makes changes easier to understand than row diffs.
- Views are reproducible: drop and rebuild from the log with fixed code; fix view bugs by replay.
- Many views, each in whatever model and store suits its queries; some can be memory-only if rebuild on restart is acceptable.
- New views and new event types can be added without touching old events.
- Mistakes are corrected by compensating events, reducing irreversible actions.
- Natural audit log; sequential appends absorb write bursts while views catch up.

Hazards and required mitigations:

- Non-determinism: view logic must not read changing external data (e.g. current exchange rate). Put the value in the event or query a versioned, time-indexed source.
- Erasure: immutable logs conflict with deletion rights. Use per-user logs, store personal data outside events, or crypto-shred (delete the key); each makes rebuilds harder.
- Side effects on replay: never resend emails or trigger external actions when rebuilding views; separate side-effecting consumers.
- Ordering: every view must process events in the same log order. This is hard in distributed systems; verify the log provides it.
- Can sit on any database, a dedicated event store, or a log-based broker (e.g. Kafka) with stream processors maintaining views.

## DataFrames, matrices, arrays

- DataFrames (R, Pandas, Spark, Dask) look like tables but are manipulated by sequences of commands on a usually private copy; suited to exploration, wrangling, and ML prep.
- Typical job: pivot relational rows into a sparse matrix with thousands of columns (too wide for a relational table), then apply linear algebra.
- Non-numeric data needs encoding: scale dates to numbers; one-hot encode small categorical sets (also handles multi-valued categories).
- Array databases (e.g. TileDB) store large numeric grids: geospatial rasters, imaging, astronomy. DataFrames are also common for financial time series.
- These are analytical/scientific models; do not use them as an OLTP store.

## Emulating one model in another

- Any model can be encoded in another (graph in two relational tables with JSON properties), but queries may become awkward. Emulate only if query complexity stays acceptable; otherwise use a specialized engine or an engine extension.
- Relational-document hybrids are often the best default: references and joins where entities are shared, JSON where structure is flexible.

## Review checklist

- What relationship types dominate (one-to-few, many-to-one, many-to-many, multi-hop)? Does the chosen model fit them?
- Are any embedded collections unbounded? Are documents kept small and rarely partially updated?
- Which fields are denormalized? For each: source of truth, update process, atomicity on crash, change rate.
- Are volatile values stored as IDs and hydrated at read time?
- Are many-to-many links stored once with secondary indexes on both directions, including nested JSON fields?
- Is the schema enforced on write or read? If on read, where is the implicit schema documented and validated, and how is legacy format handled?
- Are large migrations planned with online tooling or lazy backfill?
- Does ORM usage produce N+1 queries? Is the underlying schema still designed for other consumers?
- For recursive or variable-hop queries, is a graph language or recursive CTE with cycle handling used?
- For GraphQL: is per-field authorization, query cost limiting, and resolver batching in place?
- For event sourcing: are events validated before append, past-tense, deterministic to process, ordered for all consumers, safe to replay without side effects, and erasable for personal data?
- Is analytical modeling (star, snowflake, OBT, DataFrames) kept separate from the OLTP schema?
