---
name: c4-model
description: Create, revise, and review C4 model software architecture diagrams and supporting architecture documentation. Use when Codex needs to describe static software structure with System Context, Container, Component, Code, Deployment, System Landscape, or runtime diagrams; choose diagram scope and audience; turn codebase knowledge into C4 views; critique architecture diagrams for unclear vocabulary, missing relationships, absent technology details, or model-code gaps.
---

# C4 Model

## Overview

Use this skill to create and assess C4 model architecture diagrams for software systems. The guidance is distilled from Simon Brown's "The C4 model for visualising software architecture", parsed from `assets/c4_model.pdf` with `lit`.

## Core Workflow

1. Establish the system in scope, the audience, and whether the work is design-time, documentation of an existing system, or review of existing diagrams.
2. Use a shared vocabulary before drawing: people use software systems; software systems contain containers; containers contain components; components are implemented by code elements.
3. Start with System Context and Container diagrams for most systems. Add Component diagrams only for containers where the internal structure clarifies the story. Add Code diagrams rarely, for complex components or reusable implementation patterns.
4. Keep each diagram at one level of abstraction. Split large diagrams by bounded context, feature, use case, controller, workflow, or other focused story instead of enlarging the canvas.
5. Add enough text to remove ambiguity: every element should have a name and short responsibility; containers and components should include technology when known; important relationships should have labelled intent and, when useful, communication style or protocol.
6. Check that the diagram reflects reality: each architectural element should map to something real in the code, deployment, or ownership model.

## Reference Routing

- Read `references/vocabulary-and-levels.md` when deciding which C4 diagram level to create, what elements belong on each level, or how to model microservices, serverless functions, data stores, and shared components.
- Read `references/notation.md` when creating or improving visual notation, titles, legends, element descriptions, line labels, layout, color, boundaries, and diagram scope.
- Read `references/review-checklist.md` when reviewing diagrams or converting informal boxes-and-lines sketches into clearer C4 diagrams.

## Output Guidance

Prefer the diagram format requested by the user. If none is specified, choose a format that fits the repo or artifact:

- Use Mermaid for quick Markdown-native diagrams.
- Use PlantUML or Structurizr DSL when the project already uses architecture-as-code or needs richer C4 semantics.
- Use prose plus tables when the user is still discovering the architecture and a diagram would require guesses.

When information is missing, make placeholders explicit rather than inventing architecture. For example: `Payment Gateway [external system, provider TBD]` or `Database [relational database, exact engine TBD]`.

## Creation Checklist

Before finishing C4 work, verify:

- The diagram title includes the diagram type and system/container in scope.
- The system boundary or container boundary is explicit where the diagram zooms into something.
- People, external systems, containers, and components are not mixed accidentally.
- Lines are labelled with meaningful verbs and direction.
- Technology choices are included for Container and Component diagrams when known.
- The diagram can be read by its intended audience without verbal explanation.
- Optional diagrams are justified by value and maintainability.
