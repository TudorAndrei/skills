# Adapter

**Intent:** make an existing interface usable through the interface a client expects.

Use at integration boundaries, especially for a legacy API or third-party library. Translate semantics, units, errors, and lifecycle—not just method names.

```ts
interface PaymentGateway {
  charge(cents: number): Promise<void>;
}
class LegacyBank {
  async pay(amount: number) {
    /* amount is decimal dollars */
  }
}
class BankAdapter implements PaymentGateway {
  constructor(private readonly bank: LegacyBank) {}
  async charge(cents: number) {
    await this.bank.pay(cents / 100);
  }
}
async function checkout(gateway: PaymentGateway) {
  await gateway.charge(2599);
}
```

Keep the adapted type behind the adapter; otherwise its incompatible API leaks back to clients. Do not use an adapter merely to rename a type you control.

Source and diagrams: <https://refactoring.guru/design-patterns/adapter>
