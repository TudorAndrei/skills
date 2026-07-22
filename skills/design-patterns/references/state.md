# State

**Intent:** let an object change behavior by delegating to an object representing its current state.

Use when state-dependent conditionals spread across methods and transitions have domain meaning.

```ts
interface OrderState {
  pay(order: Order): void;
}
class Draft implements OrderState {
  pay(order: Order) {
    order.setState(new Paid());
  }
}
class Paid implements OrderState {
  pay() {
    throw new Error("already paid");
  }
}
class Order {
  private state: OrderState = new Draft();
  setState(state: OrderState) {
    this.state = state;
  }
  pay() {
    this.state.pay(this);
  }
}
```

Put transition ownership in either the context or states consistently, and test invalid transitions. Use Strategy when selection comes from outside rather than the object's evolving internal state.

Source and diagrams: <https://refactoring.guru/design-patterns/state>
