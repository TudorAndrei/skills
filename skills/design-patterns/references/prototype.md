# Prototype

**Intent:** create new objects by copying a configured exemplar.

Use when setup is costly or unknown to callers and copying is more direct than rebuilding. Define whether copies share or duplicate nested mutable state.

```ts
class InvoiceDraft {
  constructor(
    readonly currency: string,
    readonly lines: string[],
  ) {}
  clone(overrides: Partial<Pick<InvoiceDraft, "currency" | "lines">> = {}) {
    return new InvoiceDraft(overrides.currency ?? this.currency, [
      ...(overrides.lines ?? this.lines),
    ]);
  }
}
const euroTemplate = new InvoiceDraft("EUR", ["consulting"]);
const rushInvoice = euroTemplate.clone({ lines: ["consulting", "rush fee"] });
```

Do not call a shallow copy a clone if it leaks mutable nested objects. Prefer a builder when callers need to choose many independent parts.

Source and diagrams: <https://refactoring.guru/design-patterns/prototype>
