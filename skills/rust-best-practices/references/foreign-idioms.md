# Foreign Idioms

Sources: https://rust-unofficial.github.io/patterns/, https://users.rust-lang.org/t/common-newbie-mistakes-or-bad-practices/64821, https://dystroy.org/blog/how-not-to-learn-rust/, https://google.github.io/comprehensive-rust/idiomatic/welcome.html

A **foreign idiom** is code that compiles but is shaped by another language: Go, Java, Python, TypeScript, C, or C++ written in Rust syntax. Each one usually costs a clone, an allocation, a lock, or a runtime check that the type system could do for free. Use this list when you write Rust and when you review it. For each hit, rewrite to the Rust form unless the code has a stated reason.

## Ownership (any garbage-collected language)

- **Clone to satisfy the borrow checker.** A `.clone()` added only to silence an error hides an ownership design problem. Borrow instead, shorten the borrow's scope, split the struct so disjoint fields borrow separately, or move the value out with `std::mem::take` / `mem::replace`. Clone deliberately when two owners really need independent copies.
- **`Rc<RefCell<T>>` or `Arc<Mutex<T>>` by default.** These recreate a GC object graph with runtime checks. Give each value one owner and pass `&mut T` down the call stack. Across threads, send owned messages through a channel, or give each worker its own data. Keep shared mutable state for state that is truly shared, and keep the lock scope small.
- **The escalation loop.** A lifetime error fixed with `clone()`, then `Arc<Mutex<_>>`, then `Box::leak` or `unsafe`, is one design problem. Stop and restructure who owns the data.
- **References stored in structs.** A `&Foo` field forces lifetime parameters onto every struct that holds it. Own the data (`String`, `Vec<T>`, `Arc<T>`) unless the struct is a short-lived view, such as an iterator or a parser over a borrowed buffer.
- **Self-referential structs and pointer graphs.** Store nodes in a `Vec` and refer to them by index ([performance.md](performance.md), Data layout), or use `slotmap`. A linked list is almost never the right collection; use `Vec` or `VecDeque`.

## Behavior and types (Go, Java)

- **Free functions over `&mut Struct`.** `fn update(state: &mut State, x: u32)` is Go-style receiver code. Put behavior that belongs to a type in its `impl` block as a method (`state.update(x)`), and implement a trait when several types share the behavior. A free function fits when no single type owns the operation.
- **Hand-written boilerplate impls.** `#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]` replaces hand-written equivalents; derive `Serialize`, `Deserialize`, and `thiserror::Error` too.
- **Custom method names for standard conversions.** Implement the std traits so the ecosystem works with the type: `Default` over `fn empty()`, `From` / `TryFrom` over `fn from_x()`, `FromStr` over `fn parse_x()`, `Display` over `fn to_string()`, `Iterator` / `IntoIterator` over `fn items() -> Vec<T>`, `Drop` over `fn close()` that callers must remember.
- **Inheritance hierarchies and abstract base classes.** Compose structs, share behavior through traits, and use an enum when the set of kinds is closed. `Deref` to a "parent" struct is not inheritance and surprises callers.
- **`Box<dyn Trait>` for every abstraction.** Use generics or `impl Trait` when the concrete type is known at compile time, an enum when the set of kinds is closed, and `dyn Trait` when the set is open or the types must share one collection.
- **Interfaces declared up front.** A trait with one implementation and no test double is ceremony. Write the concrete type and extract a trait when the second implementation arrives.
- **Getters and setters for every field.** Inside a crate, use fields directly. At a public boundary, expose methods that keep an invariant, not a get/set pair per field ([api-design.md](api-design.md)).
- **`Manager`, `Factory`, `Helper`, `IThing` names.** A constructor is `Type::new` or a builder; a trait is named for its capability (`Read`, `Parse`), with no `I` prefix.
- **Global mutable singletons and `init()` functions.** Pass dependencies as arguments or struct fields. For a truly global value computed once, use `std::sync::OnceLock` or `LazyLock`.
- **Half-built objects.** Construct a value complete and valid (`new`, a builder, or `Default` with struct update syntax `..Default::default()`), not empty and then set field by field, and not with a separate `init()` call.

## Errors and absence (Go, Java, Python, C)

- **Error codes, `(T, error)` tuples, and `bool ok` returns.** Return `Result<T, E>` and propagate with `?`. A `match` per call that only forwards the error is Go's `if err != nil` written longhand.
- **Exceptions as control flow.** `panic!` is for bugs. Expected failures are `Result` values ([clippy.md](clippy.md) denies the panicking shortcuts).
- **Sentinel values and null.** Return `Option<T>`, not `-1`, `""`, `0`, `usize::MAX`, or a "default" that means missing.
- **Nested null-check pyramids.** Flatten with `?`, `let ... else`, `if let`, and the `Option` / `Result` combinators (`map`, `and_then`, `ok_or`, `unwrap_or_default`).
- **Defensive checks everywhere.** Validate once at the boundary into a type that cannot be invalid, and let the type carry the guarantee.

## Dynamic data (Python, JavaScript, TypeScript)

- **Strings for closed sets.** See Enums over strings in SKILL.md.
- **Maps as records.** `HashMap<String, serde_json::Value>` or `HashMap<String, String>` passed between functions is a Python dict. Deserialize into a struct with `#[derive(Deserialize)]` at the edge, and keep `Value` for data that is truly schemaless.
- **Strings as paths.** Use `Path` / `PathBuf` and `join`, not `format!("{dir}/{name}")`.
- **File names as inputs.** A function that reads data takes `impl Read` or `impl BufRead` (or `&[u8]` / `&str`), so tests pass in-memory data and callers choose the source.
- **Default and keyword arguments.** Use a builder, or an options struct that implements `Default`.
- **`Vec<char>` for text processing.** Iterate with `chars()`, `char_indices()`, or work on bytes; `Vec<char>` uses four bytes per character and copies the string.

## Signatures and loops (C, C++, Java)

- **`&String`, `&Vec<T>`, `&Box<T>` parameters.** Take `&str`, `&[T]`, and `&T`; these accept more callers through deref coercion.
- **Index loops.** `for i in 0..v.len()` with `v[i]` adds a bounds check and a panic path. Iterate (`for x in &v`, `iter().enumerate()`, `zip`, `windows`, `chunks`).
- **Out parameters.** `fn f(out: &mut Vec<T>)` is C style. Return the value, unless reusing the caller's buffer is the measured point.
- **Integer types chosen by habit.** Use `usize` for indices and lengths, and fixed widths (`u32`, `i64`) for data with a defined range, so casts stay rare ([clippy.md](clippy.md) denies `as`).
- **`unsafe` because "it works".** Every `unsafe` block needs a `// SAFETY:` comment with the invariant and an owner check from [verification.md](verification.md).
- **Explicit slicing for coercion.** `f(&array)` works; `f(&array[..])` is noise.

## Overcorrection

- **Forced functional style.** A long iterator chain with nested closures, or one that needs early return or `?` in the middle, reads better as a `for` loop.
- **Immutability everywhere.** `let mut` and `&mut self` are safe under ownership; rebuilding whole structs to avoid mutation is a foreign habit too.
