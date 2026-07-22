# Facade

**Intent:** provide a small, cohesive entry point to a complicated subsystem.

Use to give a client a common workflow while leaving specialized subsystem APIs available where needed.

```ts
class Inventory {
  reserve(sku: string) {
    return `reservation:${sku}`;
  }
}
class Billing {
  charge(cents: number) {
    return `charge:${cents}`;
  }
}
class Shipping {
  dispatch(reservation: string) {
    return `shipment:${reservation}`;
  }
}
class Checkout {
  constructor(
    private inventory: Inventory,
    private billing: Billing,
    private shipping: Shipping,
  ) {}
  placeOrder(sku: string, cents: number) {
    const reservation = this.inventory.reserve(sku);
    this.billing.charge(cents);
    return this.shipping.dispatch(reservation);
  }
}
```

Keep the facade focused on a use case, not every subsystem method. Make transaction and compensation behavior explicit instead of hiding failures.

Source and diagrams: <https://refactoring.guru/design-patterns/facade>
