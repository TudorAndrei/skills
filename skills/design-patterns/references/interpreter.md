# Interpreter

**Intent:** represent a small language's grammar as objects and evaluate sentences in that language.

Use for a stable, simple grammar such as filters, access policies, or query fragments. Define the grammar, invalid-input behavior, and evaluation context before modelling expression types.

```ts
type Context = Readonly<Record<string, boolean>>;
interface Expression {
  interpret(context: Context): boolean;
}

class Variable implements Expression {
  constructor(private readonly name: string) {}
  interpret(context: Context) {
    return context[this.name] ?? false;
  }
}
class And implements Expression {
  constructor(
    private readonly left: Expression,
    private readonly right: Expression,
  ) {}
  interpret(context: Context) {
    return this.left.interpret(context) && this.right.interpret(context);
  }
}

const mayPublish = new And(new Variable("isEditor"), new Variable("isActive"));
mayPublish.interpret({ isEditor: true, isActive: true }); // true
```

Keep expression types small, immutable, and composable. Add a parser only when callers need textual input. Prefer an existing parser, rule engine, or query language once the grammar, optimization needs, or diagnostics become substantial.

Source and further discussion: <https://en.wikipedia.org/wiki/Interpreter_pattern>
