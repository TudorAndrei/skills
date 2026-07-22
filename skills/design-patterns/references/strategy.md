# Strategy

**Intent:** encapsulate interchangeable algorithms behind a common interface.

Use when a caller selects a policy such as pricing, routing, serialization, or retry behavior without changing the context.

```ts
interface Discount {
  apply(subtotal: number): number;
}
class NoDiscount implements Discount {
  apply(subtotal: number) {
    return subtotal;
  }
}
class PercentageOff implements Discount {
  constructor(private readonly percent: number) {}
  apply(subtotal: number) {
    return subtotal * (1 - this.percent);
  }
}
class Cart {
  constructor(private discount: Discount) {}
  setDiscount(discount: Discount) {
    this.discount = discount;
  }
  total(subtotal: number) {
    return this.discount.apply(subtotal);
  }
}
```

Keep the strategy interface focused on the variable algorithm. A map of pure functions is often the clearest form for small stateless strategies.

Source and diagrams: <https://refactoring.guru/design-patterns/strategy>
