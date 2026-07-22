# Structural patterns

Choose a structural pattern when the problem is in how existing pieces fit together. Make the boundary explicit and keep clients dependent on the smallest stable interface.

| Need                                                       | Pattern   | Reference                    |
| ---------------------------------------------------------- | --------- | ---------------------------- |
| Convert an existing interface to the one clients need      | Adapter   | [adapter.md](adapter.md)     |
| Vary abstraction and platform implementation independently | Bridge    | [bridge.md](bridge.md)       |
| Treat individual objects and trees uniformly               | Composite | [composite.md](composite.md) |
| Add behavior by wrapping rather than subclassing           | Decorator | [decorator.md](decorator.md) |
| Offer one simple entry point over a subsystem              | Facade    | [facade.md](facade.md)       |
| Share immutable intrinsic data across many objects         | Flyweight | [flyweight.md](flyweight.md) |
| Stand in for an object to control access or lifecycle      | Proxy     | [proxy.md](proxy.md)         |
