# Behavioral patterns

Choose a behavioral pattern when collaborators, algorithms, iteration, or state transitions change independently. Keep protocol ownership and failure behavior explicit.

| Need                                                       | Pattern                 | Reference                                                |
| ---------------------------------------------------------- | ----------------------- | -------------------------------------------------------- |
| Pass a request through ordered potential handlers          | Chain of Responsibility | [chain-of-responsibility.md](chain-of-responsibility.md) |
| Represent an action as data                                | Command                 | [command.md](command.md)                                 |
| Represent and evaluate sentences in a small language       | Interpreter             | [interpreter.md](interpreter.md)                         |
| Traverse an aggregate without exposing its representation  | Iterator                | [iterator.md](iterator.md)                               |
| Centralize many-to-many coordination                       | Mediator                | [mediator.md](mediator.md)                               |
| Save and restore state without exposing internals          | Memento                 | [memento.md](memento.md)                                 |
| Notify dependents after a change                           | Observer                | [observer.md](observer.md)                               |
| Change behavior as an object's internal state changes      | State                   | [state.md](state.md)                                     |
| Swap an algorithm behind a stable interface                | Strategy                | [strategy.md](strategy.md)                               |
| Fix an algorithm's skeleton while varying individual steps | Template Method         | [template-method.md](template-method.md)                 |
| Add operations to a stable object structure                | Visitor                 | [visitor.md](visitor.md)                                 |
