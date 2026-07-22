# Visitor

**Intent:** add operations to a stable set of object types by moving each operation into a visitor.

Use when the element hierarchy changes rarely but operations over it change often. The trade-off reverses if new element types are frequent.

```ts
interface ShapeVisitor<R> {
  circle(shape: Circle): R;
  rectangle(shape: Rectangle): R;
}
interface Shape {
  accept<R>(visitor: ShapeVisitor<R>): R;
}
class Circle implements Shape {
  constructor(readonly radius: number) {}
  accept<R>(visitor: ShapeVisitor<R>) {
    return visitor.circle(this);
  }
}
class Rectangle implements Shape {
  constructor(
    readonly width: number,
    readonly height: number,
  ) {}
  accept<R>(visitor: ShapeVisitor<R>) {
    return visitor.rectangle(this);
  }
}
class Area implements ShapeVisitor<number> {
  circle(s: Circle) {
    return Math.PI * s.radius ** 2;
  }
  rectangle(s: Rectangle) {
    return s.width * s.height;
  }
}
```

Use the visitor interface to make missing cases compile-time visible. Do not use it for a hierarchy with frequent new element types unless that trade-off is accepted.

Source and diagrams: <https://refactoring.guru/design-patterns/visitor>
