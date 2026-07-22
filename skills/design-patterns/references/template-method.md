# Template Method

**Intent:** define an algorithm's fixed sequence in a base class while subclasses provide selected steps.

Use when variants share a stable workflow and inheritance is an appropriate extension mechanism.

```ts
abstract class ImportJob {
  run(raw: string) {
    const rows = this.parse(raw);
    return rows.filter((row) => this.valid(row)).map((row) => this.normalize(row));
  }
  protected abstract parse(raw: string): string[];
  protected valid(row: string) {
    return row.length > 0;
  }
  protected normalize(row: string) {
    return row.trim();
  }
}
class CsvImport extends ImportJob {
  protected parse(raw: string) {
    return raw.split("\n");
  }
}
```

Keep the template method small and document hooks plus their invariants. Prefer Strategy or composition when independent variations need to be combined at runtime.

Source and diagrams: <https://refactoring.guru/design-patterns/template-method>
