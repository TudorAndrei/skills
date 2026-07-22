# Observer

**Intent:** notify subscribed dependents when a subject changes.

Use when a subject should publish facts without knowing which listeners react. Define delivery order, sync/async behavior, failure isolation, and unsubscribe lifecycle.

```ts
type Listener<T> = (event: T) => void;
class Subject<T> {
  private listeners = new Set<Listener<T>>();
  subscribe(listener: Listener<T>) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
  publish(event: T) {
    for (const listener of this.listeners) listener(event);
  }
}
const orders = new Subject<{ id: string }>();
const unsubscribe = orders.subscribe((order) => console.log(`index ${order.id}`));
orders.publish({ id: "A-12" });
unsubscribe();
```

Avoid retaining listeners forever; returning an unsubscribe function makes ownership visible. Use Mediator when the notification must coordinate several peers.

Source and diagrams: <https://refactoring.guru/design-patterns/observer>
