# Singleton

**Intent:** ensure one accessible instance and centralize its lifecycle.

Use sparingly for genuinely process-wide coordination such as an in-process registry. For application services, pass a dependency explicitly so tests and lifetimes remain controllable.

```ts
class MetricsRegistry {
  private static instance?: MetricsRegistry;
  private counts = new Map<string, number>();
  static getInstance() {
    return (this.instance ??= new MetricsRegistry());
  }
  increment(name: string) {
    this.counts.set(name, (this.counts.get(name) ?? 0) + 1);
  }
  value(name: string) {
    return this.counts.get(name) ?? 0;
  }
  private constructor() {}
}
```

Account for initialization order, test isolation, and concurrency in the target runtime. A module-level instance has the same trade-offs.

Source and diagrams: <https://refactoring.guru/design-patterns/singleton>
