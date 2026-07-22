# Composite

**Intent:** compose objects into a tree and let clients treat leaves and containers uniformly.

Use for hierarchies such as file trees, menu trees, or grouped UI elements when the same client operation applies at every level.

```ts
interface PriceNode {
  total(): number;
}
class Item implements PriceNode {
  constructor(private readonly price: number) {}
  total() {
    return this.price;
  }
}
class Bundle implements PriceNode {
  constructor(private readonly children: PriceNode[]) {}
  total() {
    return this.children.reduce((sum, child) => sum + child.total(), 0);
  }
}
const cart: PriceNode = new Bundle([new Item(10), new Bundle([new Item(5)])]);
```

Keep the common interface narrow. Decide separately whether containers may expose child-management methods; forcing leaf objects to support them can weaken type safety.

Source and diagrams: <https://refactoring.guru/design-patterns/composite>
