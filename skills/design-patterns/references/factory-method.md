# Factory Method

**Intent:** defer selection of a concrete product to a creator method.

Use when client logic must work with a product interface but the product depends on a creator subtype, configuration, or environment. Do not use it for a single fixed product.

```ts
interface Transport {
  deliver(): string;
}
class Truck implements Transport {
  deliver() {
    return "road";
  }
}
class Ship implements Transport {
  deliver() {
    return "sea";
  }
}

abstract class Logistics {
  abstract createTransport(): Transport;
  planDelivery() {
    return this.createTransport().deliver();
  }
}
class RoadLogistics extends Logistics {
  createTransport() {
    return new Truck();
  }
}
```

Keep `planDelivery` dependent on `Transport`, not `Truck`. A factory function is often simpler when subclassing a creator adds no value.

Source and diagrams: <https://refactoring.guru/design-patterns/factory-method>
