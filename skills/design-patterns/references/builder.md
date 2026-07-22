# Builder

**Intent:** construct a complex object through named, incremental steps.

Use when constructor parameters become unclear, optional parts interact, or the same construction process must produce different representations.

```ts
class Report {
  constructor(
    readonly title: string,
    readonly sections: string[],
    readonly footer?: string,
  ) {}
}
class ReportBuilder {
  private title = "";
  private sections: string[] = [];
  private footer?: string;
  titled(title: string) {
    this.title = title;
    return this;
  }
  addSection(text: string) {
    this.sections.push(text);
    return this;
  }
  withFooter(text: string) {
    this.footer = text;
    return this;
  }
  build() {
    return new Report(this.title, [...this.sections], this.footer);
  }
}
const report = new ReportBuilder().titled("Q2").addSection("Revenue").build();
```

Validate required fields in `build`; make reuse and mutability rules explicit. Prefer an options object for a small, independent parameter set.

Source and diagrams: <https://refactoring.guru/design-patterns/builder>
