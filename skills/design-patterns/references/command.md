# Command

**Intent:** turn a request into an object that can be queued, logged, retried, composed, or undone.

Use when an action must outlive its caller or be handled by generic infrastructure.

```ts
interface Command {
  execute(): void;
  undo(): void;
}
class TextBuffer {
  value = "";
}
class InsertText implements Command {
  constructor(
    private readonly buffer: TextBuffer,
    private readonly text: string,
  ) {}
  execute() {
    this.buffer.value += this.text;
  }
  undo() {
    this.buffer.value = this.buffer.value.slice(0, -this.text.length);
  }
}
class History {
  private done: Command[] = [];
  run(command: Command) {
    command.execute();
    this.done.push(command);
  }
  undo() {
    this.done.pop()?.undo();
  }
}
```

Capture enough pre-action state for a correct undo, or state clearly that it is not reversible. Prefer a function when queueing, auditing, and undo are unnecessary.

Source and diagrams: <https://refactoring.guru/design-patterns/command>
