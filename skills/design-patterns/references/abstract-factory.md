# Abstract Factory

**Intent:** create related products without naming their concrete classes.

Use when a client needs a compatible family (for example, platform widgets or cloud resources) and must not mix families accidentally.

```ts
interface Button {
  render(): string;
}
interface Dialog {
  open(): string;
}
interface UiFactory {
  button(): Button;
  dialog(): Dialog;
}

class MacUi implements UiFactory {
  button() {
    return { render: () => "mac button" };
  }
  dialog() {
    return { open: () => "mac dialog" };
  }
}
function renderSettings(ui: UiFactory) {
  return `${ui.button().render()} / ${ui.dialog().open()}`;
}
```

Add a product family only when its products must remain coordinated. A single factory method is usually enough for one product type.

Source and diagrams: <https://refactoring.guru/design-patterns/abstract-factory>
