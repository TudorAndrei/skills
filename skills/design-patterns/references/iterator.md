# Iterator

**Intent:** traverse an aggregate without exposing its internal representation.

Use when callers need a stable traversal protocol while the collection structure or traversal order can vary.

```ts
class Queue<T> implements Iterable<T> {
  constructor(private readonly items: T[]) {}
  *[Symbol.iterator](): Iterator<T> {
    for (const item of this.items) yield item;
  }
}
for (const job of new Queue(["resize", "email"])) console.log(job);
```

Specify mutation behavior during iteration: fail, snapshot, or live view. In languages with built-in iterators, implement the native protocol instead of inventing a parallel one.

Source and diagrams: <https://refactoring.guru/design-patterns/iterator>
