# C4 Diagram Review Checklist

Use this checklist when reviewing an existing architecture diagram or converting an informal sketch into a C4 diagram set.

## Scope And Level

- Is the diagram type explicit?
- Is the system or container in scope clear?
- Does the diagram stay at one abstraction level?
- Are people, systems, containers, components, and code elements used according to the shared vocabulary?
- Does each Component diagram zoom into exactly one container?
- Does each Container diagram correspond to one system boundary from the System Context diagram?

## Audience

- Can the intended audience understand the diagram without a presenter?
- Is the level of technical detail appropriate for that audience?
- Are optional diagrams justified by the value they add and the cost of maintaining them?

## Elements

- Does each element have a clear name?
- Does each element have a concise responsibility or description?
- Are technology choices shown for containers and components when known?
- Are technology options or TBDs called out when decisions are not yet made?
- Are external systems and third-party services distinguished from owned systems?
- Are cloud services modeled as data stores or runtime containers where the team owns the relevant schema, bucket, queue, database, or deployed unit?

## Relationships

- Are important lines labelled?
- Do relationship labels explain purpose rather than merely saying `uses`?
- Does each arrow direction match the label?
- Are communication mechanisms, protocols, or sync/async styles included where they matter?
- Are multiple relationships split only when precision adds value?

## Boundaries

- Are enterprise, system, container, deployment, trust, or network boundaries shown where relevant?
- Does the boundary on a Container diagram match the system box on the System Context diagram?
- Does the boundary on a Component diagram match a container box on the Container diagram?

## Reality Checks

- For existing systems: does the diagram reflect how the software is actually built and deployed?
- For proposed systems: would the team code and deploy it the way the diagram shows?
- Can every component map to a real package, namespace, module, annotation, folder, service, or other identifiable code structure?
- Are shared components shown where they execute rather than as imaginary separate runtimes?
- Are architecture concepts made evident in code through names, packaging, annotations, metadata, or documented mapping?
- Are deployment diagrams mapping software containers to infrastructure rather than only showing infrastructure icons?

## Notation

- Is there a title?
- Is there a legend for shapes, colors, line styles, borders, and icons?
- Are colors and shapes supplementary rather than required to understand the diagram?
- Are acronyms expanded for the intended audience?
- Are similar elements roughly similar sizes unless size has explicit meaning?

## Clutter

- Is the diagram trying to tell too many stories?
- Are cross-cutting concerns such as logging, monitoring, security, and shared libraries shown only when they help?
- Would splitting the diagram by feature, use case, bounded context, workflow, or entry point make it clearer?
- Are details better moved to a Deployment, runtime, domain, workflow, or supplementary documentation view?

## Review Output

When reporting findings, prioritize:

1. Incorrect abstraction level or misleading model-code/deployment mismatch.
2. Missing scope, boundary, or ownership information.
3. Ambiguous elements or relationships.
4. Missing technology details that affect implementation reality.
5. Notation and readability issues.

Suggest concrete fixes in the same diagram format when possible.
