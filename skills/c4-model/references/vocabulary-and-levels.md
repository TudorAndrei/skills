# Vocabulary And C4 Levels

This reference summarizes the C4 static-structure vocabulary and the usual purpose, contents, audience, and necessity of each level.

## Shared Vocabulary

Use the same abstractions consistently across diagrams:

- Person: a human user, role, actor, persona, or group that uses a software system.
- Software system: the highest-level unit that delivers value to users. A System Context diagram treats the system in scope as one box.
- Container: an application or data store that hosts code or data and must be running for the system to work. Containers are usually separately deployable or separately runnable.
- Component: a coarse-grained grouping of related functionality inside a container, encapsulated behind a well-defined interface. Components are not separately deployable in C4; their container is the deployable unit.
- Code element: the programming-language-level implementation of components, such as classes, interfaces, objects, functions, modules, files, packages, or namespaces.

Useful rule: a software system is made of containers; containers contain components; components are implemented by code elements.

## Modeling Decisions

- Treat owned microservices as containers inside the system. Treat third-party or separately owned microservices as external software systems.
- Treat serverless functions as containers when they are separately deployable/runtime units in the system.
- Treat a data store as a container when the team owns or controls the schema, bucket, database, queue, or store, even if hosted by a cloud service.
- Treat libraries, packages, JARs, DLLs, and shared modules as components only when discussing the internals of a container; do not model them as containers unless they run independently.
- Include shared components where they execute. If a logging library is deployed inside two web applications, show it inside each relevant container or annotate it as shared; do not draw it as a separate runtime unless it really is one.
- Define local terminology when an organization already uses different terms. The C4 hierarchy matters more than the literal word choice.

## Level 1: System Context

Intent:

- Show the software system in scope and how it fits into the surrounding environment.
- Answer what the system is, who uses it, and what other systems it interacts with.

Include:

- The system in scope.
- People who use it.
- External software systems it depends on or communicates with.
- Optional enterprise or organizational boundary.
- High-level relationship labels that explain purpose.

Avoid:

- Internal containers, components, protocols, ports, and implementation details unless they are essential to context.

Audience:

- Technical and non-technical stakeholders inside and outside the delivery team.

Use:

- Required for all software systems.

## Level 2: Container

Intent:

- Open the system boundary and show the high-level technical building blocks.
- Answer the system shape, key technology decisions, responsibility distribution, container communication, and where developers write code.

Include:

- Containers such as web apps, mobile apps, desktop apps, APIs, services, batch jobs, databases, file systems, queues, and content stores.
- The same relevant people and external systems from the System Context diagram for continuity.
- A software system boundary around the containers.
- For each container: name, technology or technology options, and concise responsibility.
- Relationship labels with purpose and useful communication details such as sync/async, protocol, API style, or port.

Avoid:

- Physical instance counts, clustering, failover, node topology, and infrastructure mapping. Put those on Deployment diagrams.
- Log file destinations unless the storage is business-critical architecture.

Audience:

- Technical stakeholders, developers, operations, support, and adjacent teams.

Use:

- Required for all software systems.

## Level 3: Component

Intent:

- Zoom into one container and show its internal components.
- Answer what components the container contains, whether components have a home, and how the container works at a high level.

Include:

- One container's boundary and the components inside it.
- Relevant people, external systems, and other containers around the boundary when they help explain interactions.
- For each component: name, implementation technology where useful, and concise responsibility.
- Relationships with purpose and useful communication style.
- Architectural style as implemented, such as layered, hexagonal, ports and adapters, feature slices, or components.

Handle clutter:

- Omit low-value cross-cutting components, add a note, or show them via symbols/color explained in a legend.
- Split large component diagrams by business area, feature, bounded context, use case, controller, or workflow.
- Create separate diagrams for variant implementations only when those variants materially change the story.

Audience:

- Technical people within the software development team.

Use:

- Optional for simple containers, data stores, and many microservices.
- Most useful for monoliths, complex containers, up-front design discussions, onboarding, and architecture archaeology.

## Level 4: Code

Intent:

- Zoom into one component and show its implementation structure.

Include:

- A tightly scoped code-level view, often a UML class diagram for object-oriented code.
- Only attributes, methods, relationships, or functions needed for the story.

Avoid:

- Whole-application class diagrams.
- Auto-generated diagrams with every code detail unless the user explicitly needs exhaustive reverse engineering.

Audience:

- Software developers working near the component.

Use:

- Optional and generally uncommon. Prefer source code and IDE navigation unless a diagram clarifies a complex component or pattern.

## Deployment Diagrams

Use Deployment diagrams to map C4 software systems or containers onto deployment nodes.

Include:

- Container or software system instances.
- Deployment nodes such as physical servers, virtual machines, PaaS services, Docker containers, Kubernetes pods/namespaces, execution environments, database servers, or application servers.
- Nested nodes where helpful.
- Infrastructure nodes such as DNS, load balancers, routers, firewalls, VPCs, subnets, clusters, hostnames, IPs, scaling limits, or replica counts when they help tell the story.

Do not stop at cloud vendor icons. Show how the team's applications and data stores use that infrastructure.

## Other Useful Diagrams

- System Landscape: show a broader enterprise or product ecosystem without focusing on a single software system.
- Runtime or behaviour: use sequence/collaboration diagrams over C4 elements to show important scenarios, user stories, or use cases.
- Business process/workflow: use flowcharts or activity diagrams for non-technical process narratives.
- Domain model: summarize important domain concepts and relationships.
- UI mockups/wireframes: use when user interaction and screen flow are the story; C4 does not replace these.
