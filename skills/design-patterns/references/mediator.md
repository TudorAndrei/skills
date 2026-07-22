# Mediator

**Intent:** centralize a collaboration protocol so peer objects do not depend directly on each other.

Use when many components coordinate through events or rules and direct links become tangled. Keep the mediator focused on one coherent workflow.

```ts
class Dialog {
  submitEnabled = false;
  onChanged(source: "email" | "terms", value: boolean) {
    if (source === "email") this.emailValid = value;
    else this.termsAccepted = value;
    this.submitEnabled = this.emailValid && this.termsAccepted;
  }
  private emailValid = false;
  private termsAccepted = false;
}
class Checkbox {
  constructor(
    private readonly dialog: Dialog,
    private readonly role: "email" | "terms",
  ) {}
  set(value: boolean) {
    this.dialog.onChanged(this.role, value);
  }
}
```

Avoid turning the mediator into an unbounded god object. For one-way broadcast with no coordination rules, use Observer instead.

Source and diagrams: <https://refactoring.guru/design-patterns/mediator>
