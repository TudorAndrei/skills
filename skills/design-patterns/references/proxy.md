# Proxy

**Intent:** substitute an object with a stand-in that controls access while preserving its interface.

Use for lazy loading, authorization, caching, remote access, or reference counting. Identify which operations may be delayed, denied, or observed.

```ts
interface DocumentStore {
  read(id: string): Promise<string>;
}
class RemoteStore implements DocumentStore {
  async read(id: string) {
    return `remote document ${id}`;
  }
}
class AuthorizedStore implements DocumentStore {
  constructor(
    private readonly user: { canRead: boolean },
    private readonly inner: DocumentStore,
  ) {}
  async read(id: string) {
    if (!this.user.canRead) throw new Error("forbidden");
    return this.inner.read(id);
  }
}
```

Expose latency, cache staleness, and authorization failures as part of the contract. A decorator adds behavior too, but a proxy specifically controls access to the subject.

Source and diagrams: <https://refactoring.guru/design-patterns/proxy>
