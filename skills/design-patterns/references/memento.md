# Memento

**Intent:** capture and restore an object's state without exposing its representation to the caretaker.

Use for undo, checkpoints, or draft recovery where snapshots must not let external code mutate internal invariants.

```ts
type EditorMemento = Readonly<{ text: string; cursor: number }>;
class Editor {
  private text = "";
  private cursor = 0;
  type(value: string) {
    this.text = this.text.slice(0, this.cursor) + value + this.text.slice(this.cursor);
    this.cursor += value.length;
  }
  save(): EditorMemento {
    return Object.freeze({ text: this.text, cursor: this.cursor });
  }
  restore(snapshot: EditorMemento) {
    this.text = snapshot.text;
    this.cursor = snapshot.cursor;
  }
}
class History {
  private snapshots: EditorMemento[] = [];
  push(m: EditorMemento) {
    this.snapshots.push(m);
  }
  pop() {
    return this.snapshots.pop();
  }
}
```

Choose snapshot frequency, storage limits, and deep-copy semantics deliberately. Commands can be preferable when inverse operations are cheaper than snapshots.

Source and diagrams: <https://refactoring.guru/design-patterns/memento>
