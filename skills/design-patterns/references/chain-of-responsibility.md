# Chain of Responsibility

**Intent:** pass a request along an ordered chain until a handler deals with it or the chain ends.

Use when handlers are optional, ordered, or independently configured, such as validation, authorization, or event processing.

```ts
type Request = { user?: string; body?: string };
interface Handler {
  setNext(next: Handler): Handler;
  handle(request: Request): string | undefined;
}
abstract class BaseHandler implements Handler {
  private next?: Handler;
  setNext(next: Handler) {
    this.next = next;
    return next;
  }
  handle(request: Request) {
    return this.next?.handle(request);
  }
}
class AuthHandler extends BaseHandler {
  handle(request: Request) {
    return request.user ? super.handle(request) : "unauthorized";
  }
}
class BodyHandler extends BaseHandler {
  handle(request: Request) {
    return request.body ? "accepted" : "missing body";
  }
}
```

Define whether zero, one, or many handlers may process a request. Use a simple ordered list of functions when objects add no useful state or reuse.

Source and diagrams: <https://refactoring.guru/design-patterns/chain-of-responsibility>
