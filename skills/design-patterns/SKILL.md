---
name: design-patterns
description: Select, explain, implement, refactor to, or review the 23 classic GoF design patterns. Use when a software-design request involves object creation, adapting or composing interfaces, changing behavior, decoupling collaborators, replacing conditionals, or evaluating whether a named pattern is appropriate.
---

# Design Patterns

Use patterns to make a concrete pressure in the code explicit; do not introduce one merely to label a design.

## Workflow

1. State the changing requirement, current coupling, and constraints (language features, lifetime, concurrency, performance, public API).
2. Start from the category table, then read only the candidate pattern reference(s).
3. Prefer the smallest design that separates the volatile concern. Preserve behavior with focused tests before and after a refactor.
4. Explain the roles using the names in the chosen reference, map them to the codebase, and call out the trade-offs.
5. Reject a pattern when a direct function, data structure, or language feature makes the solution clearer.

All examples are original TypeScript sketches. Translate the roles and dependency directions, not necessarily their syntax. References link to Refactoring.Guru where available; Interpreter links to Wikipedia because Refactoring.Guru's catalog omits it.

## Pick a category

| Pressure                                                        | Read                                         |
| --------------------------------------------------------------- | -------------------------------------------- |
| Vary, defer, or control object construction                     | [creational index](references/creational.md) |
| Make object structures or incompatible interfaces work together | [structural index](references/structural.md) |
| Vary algorithms, collaboration, control flow, or state          | [behavioral index](references/behavioral.md) |

## References

### Creational

- [Factory Method](references/factory-method.md)
- [Abstract Factory](references/abstract-factory.md)
- [Builder](references/builder.md)
- [Prototype](references/prototype.md)
- [Singleton](references/singleton.md)

### Structural

- [Adapter](references/adapter.md)
- [Bridge](references/bridge.md)
- [Composite](references/composite.md)
- [Decorator](references/decorator.md)
- [Facade](references/facade.md)
- [Flyweight](references/flyweight.md)
- [Proxy](references/proxy.md)

### Behavioral

- [Chain of Responsibility](references/chain-of-responsibility.md)
- [Command](references/command.md)
- [Interpreter](references/interpreter.md)
- [Iterator](references/iterator.md)
- [Mediator](references/mediator.md)
- [Memento](references/memento.md)
- [Observer](references/observer.md)
- [State](references/state.md)
- [Strategy](references/strategy.md)
- [Template Method](references/template-method.md)
- [Visitor](references/visitor.md)
