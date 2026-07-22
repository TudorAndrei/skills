# Decorator

**Intent:** add responsibilities by wrapping an object with the same interface.

Use when behavior is optional or combinable at runtime and subclass combinations would grow quickly. Preserve the wrapped object's contract.

```ts
interface Notifier {
  send(message: string): void;
}
class EmailNotifier implements Notifier {
  send(message: string) {
    console.log(`email: ${message}`);
  }
}
class NotifierDecorator implements Notifier {
  constructor(protected readonly inner: Notifier) {}
  send(message: string) {
    this.inner.send(message);
  }
}
class SlackNotifier extends NotifierDecorator {
  send(message: string) {
    super.send(message);
    console.log(`slack: ${message}`);
  }
}
```

Document ordering and error rules because wrapper order is observable. Prefer middleware when the operation is a pipeline rather than an object's stable capability.

Source and diagrams: <https://refactoring.guru/design-patterns/decorator>
