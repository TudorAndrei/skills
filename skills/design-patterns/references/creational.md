# Creational patterns

Choose a creational pattern when construction is itself the volatile concern. Keep the constructed object's public behavior separate from the code that decides which concrete object exists.

| Need                                              | Pattern          | Reference                                  |
| ------------------------------------------------- | ---------------- | ------------------------------------------ |
| Let subclasses or creators choose one product     | Factory Method   | [factory-method.md](factory-method.md)     |
| Create compatible families of related products    | Abstract Factory | [abstract-factory.md](abstract-factory.md) |
| Assemble a complex value step by step             | Builder          | [builder.md](builder.md)                   |
| Create an object by copying a configured exemplar | Prototype        | [prototype.md](prototype.md)               |
| Coordinate access to one process-wide instance    | Singleton        | [singleton.md](singleton.md)               |

Prefer dependency injection over a Singleton for ordinary dependencies. Prefer a plain constructor or factory function when there is no genuine variation in construction.
