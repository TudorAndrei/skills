# Flyweight

**Intent:** share immutable intrinsic state among many fine-grained objects.

Use only after measuring a memory or allocation problem. Separate shareable state from context that varies per occurrence.

```ts
type Glyph = Readonly<{ char: string; font: string }>;
class GlyphFactory {
  private cache = new Map<string, Glyph>();
  get(char: string, font: string): Glyph {
    const key = `${font}:${char}`;
    return (
      this.cache.get(key) ??
      (() => {
        const glyph = Object.freeze({ char, font });
        this.cache.set(key, glyph);
        return glyph;
      })()
    );
  }
}
type PositionedGlyph = { glyph: Glyph; x: number; y: number }; // extrinsic state
```

Make the shared object immutable and bound the cache if inputs are unbounded. Do not use this pattern when ordinary object allocation is not a demonstrated cost.

Source and diagrams: <https://refactoring.guru/design-patterns/flyweight>
