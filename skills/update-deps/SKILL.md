---
name: update-deps
description: "Guide dependency updates across any project interactively. Use this skill whenever the user asks to check, update, or bump dependencies — whether in Python, JavaScript, Go, Rust, Ruby, Java, or any other language. This skill detects the package manager, researches what's outdated and why, identifies breaking changes and compatibility issues, and helps the user decide which dependencies to update and in what order. The goal is collaborative decision-making, not automatic updates."
compatibility:
  required_tools: []
  languages:
    [
      "Python",
      "JavaScript/TypeScript",
      "Go",
      "Rust",
      "Ruby",
      "Java",
      "PHP",
      "C#/.NET",
      "Swift",
      "Kotlin",
    ]
  package_managers:
    [
      "npm/yarn/pnpm",
      "pip",
      "poetry",
      "cargo",
      "go get",
      "gem",
      "maven",
      "gradle",
      "composer",
      "cocoapods",
      "nuget",
      "swift package manager",
    ]
---

# Guide Dependency Updates Interactively

Your role is to be a guide and sounding board as the user decides what to update. Don't just produce a report and disappear — engage in conversation, ask clarifying questions, weigh tradeoffs, and help the user make informed decisions about their dependencies.

The core insight: **updating dependencies is a choice, not an obligation**. Some updates bring clear benefits (security fixes, performance improvements). Others introduce risk (breaking changes, new bugs). Your job is to help the user navigate this decision space.

## Workflow

### Step 1: Detect the project's package manager

Find the dependency configuration files:

- **JavaScript/TypeScript**: `package.json` (npm/yarn/pnpm), `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- **Python**: `requirements.txt`, `setup.py`, `pyproject.toml`, `Poetry.lock`, `Pipfile`
- **Rust**: `Cargo.toml`, `Cargo.lock`
- **Go**: `go.mod`, `go.sum`
- **Ruby**: `Gemfile`, `Gemfile.lock`
- **Java**: `pom.xml` (Maven), `build.gradle` (Gradle)
- **PHP**: `composer.json`, `composer.lock`
- **C#/.NET**: `.csproj`, `.sln`, `packages.config`
- **Swift**: `Package.swift`, `Package.resolved`
- **Other**: Search online for "[language] dependency file" if unsure

If multiple package managers exist, ask the user which one they want to focus on.

If you don't recognize the ecosystem, **search online** for "[package manager] how to list outdated packages" and follow the documentation.

### Step 2: List what's outdated

Use the package manager's built-in command:

- **npm/yarn/pnpm**: `npm outdated`, `yarn outdated`, `pnpm outdated`
- **pip**: `pip list --outdated`
- **Rust**: `cargo outdated`
- **Go**: `go get -u -d ./...` (dry-run)
- **Ruby**: `bundle outdated`
- **Maven**: `mvn versions:display-dependency-updates`
- **Gradle**: `./gradlew dependencyUpdates`
- **Poetry**: `poetry show --outdated`

If the command isn't available, search for it online.

Present the findings as a table:
| Package | Current | Latest | Type |
| --- | --- | --- | --- |
| pkg-name | 1.2.3 | 1.3.0 | minor |
| other-pkg | 2.0.0 | 3.0.0 | major |

### Step 3: Research changelogs and breaking changes

For **each** outdated dependency, dig into what changed:

1. **Find the changelog** — Look for CHANGELOG.md/HISTORY.md in the repo, or check:
   - GitHub releases page (`github.com/user/repo/releases`)
   - Package registry (npmjs.com, PyPI.org, crates.io, etc.)
   - The package's official website or blog

2. **Identify what matters**:
   - **Breaking changes** — API changes that could break the user's code
   - **Security fixes** — Vulnerabilities being patched (usually worth applying)
   - **Bug fixes & improvements** — Generally safe
   - **Deprecations** — Warnings about future breaking changes
   - **Dependencies changes** — New dependencies added or removed

3. **Classify the risk**: Is this a low-risk update (patch with no breaking changes) or high-risk (major version with API changes)?

If you can't find a changelog, say so honestly and suggest the user review the repo directly or skip the package for now.

### Step 4: Check cross-compatibility

Before suggesting an update, verify it won't break other dependencies:

1. **Check what the new version requires** — Look at its `package.json`, `setup.py`, `Cargo.toml`, etc.
   - Example: "pkg-a@3.0.0 requires pkg-b@^2.0"
2. **Compare with what the project has** — Will updating pkg-a force you to update pkg-b too?
3. **Look for hidden conflicts** — Does the new version require a newer Node/Python/runtime version?

If there are conflicts, explain them clearly: "Updating X to Y requires also updating Z, which is a major version bump."

### Step 5: Track breaking changes in the codebase

For packages with breaking changes, verify whether those changes actually affect this project:

1. **Extract breaking changes from the changelog** — List the specific API changes, removed methods/functions, changed parameters, config format changes, etc.
   - Example: "Method `foo()` renamed to `bar()`" or "Config file format changed from YAML to JSON"

2. **Search the codebase for usage** — Find where this package is imported, used, and configured:
   - Search for imports: `import pkg-name`, `from pkg-name import X`, `require('pkg-name')`, etc.
   - Search for the specific APIs mentioned in breaking changes: `foo()`, `config.old_key`, etc.
   - Check configuration files that might reference the package

3. **Map breaking changes to actual usage**:
   - If the changelog says `Method foo() was removed` and you find calls to `foo()` in the code → this WILL break
   - If the changelog says `Parameter order changed in bar()` but the code uses keyword arguments → might be OK
   - If the changelog says `Config format changed` but the code auto-generates config → might be OK

4. **Create a breaking change impact report** for packages with changes:

```
## pkg-name v2.0.0 Breaking Changes

### Changes detected in changelog
- Method `foo()` renamed to `bar()`
- `config.old_key` removed, replaced with `config.new_key`
- Default behavior changed from sync to async

### Impact on this codebase
- **Uses `foo()` in**: src/service.ts (line 45), tests/service.test.ts (line 12)
  → WILL BREAK - needs refactoring to `bar()`
- **Uses `config.old_key` in**: config.yaml, .env (line 3)
  → WILL BREAK - needs config update
- **Calls `async_func()` in**: src/main.ts (line 8, awaited correctly)
  → OK - already using async pattern

### Summary
Update requires: 2 code changes, 1 config change
Estimated effort: ~15 minutes
```

5. **Flag issues clearly**: Distinguish between:
   - "WILL BREAK" → used in code, needs changes
   - "MIGHT BREAK" → used but depends on context (edge cases, conditional usage)
   - "OK" → not used or already compatible
   - "UNCLEAR" → can't determine without running code

### Step 6: Engage the user in dialogue

Don't just dump information. Instead, present findings and **ask for input**:

**After listing outdated packages:**

- "I found 12 outdated packages. Which ones are you most concerned about?"
- "Are there any packages you intentionally pinned to old versions?"

**After researching a package:**

- "pkg-name has a major version bump from 2.x to 3.x with breaking API changes. Does your code depend on the old API, or are you isolated from it?"
- "There's a security fix in pkg-name. Should we prioritize this one?"

**When there are conflicts:**

- "Updating A requires updating B, which is also a major version. Want to tackle both together, or skip A for now?"

**When deciding order:**

- "Should we update the safe patches first and test, then tackle the major versions?"
- "Any packages you're worried about that we should update carefully?"

### Step 7: Build a plan together

Synthesize the research into a proposed update strategy:

**Example dialogue:**

> "Based on what we found, here's what I'm thinking:
>
> 1. Update these patches (all low-risk): pkg1, pkg2, pkg3
> 2. Update pkg4 to a new minor version — it has a breaking API change, but I found it's only used in one test file, so it should be a quick fix
> 3. Skip pkg5 for now because it requires a runtime upgrade you may not want
> 4. pkg6 has a security fix — I'd recommend updating this one. It has breaking changes in the config format, but they're localized to config.yaml, so minimal code changes needed
>
> Does this order make sense? Want to adjust anything?"

Then let the user steer. Maybe they say:

- "Actually, skip pkg4 for now" → respect that
- "Let's do pkg6 first because security" → adjust the order
- "Can you help me understand the breaking change in pkg2?" → dig deeper

### Step 8: Apply updates (with confirmation)

Only update files when the user explicitly asks. When they do:

1. Update the dependency file (`package.json`, `requirements.txt`, `Cargo.toml`, etc.)
2. Run the package manager's install/update command to regenerate lock files
3. Commit with a message describing what was updated: `chore: update dependencies (pkg1, pkg2 to latest)`
4. Suggest running the test suite to verify nothing broke

## Key Principles

- **Ask before updating** — Never make changes without confirmation
- **Explain the why** — Don't just say "major version bump"; explain what's actually changing and why it matters
- **Respect the user's risk tolerance** — Some users want cutting-edge; others prefer stability. Adjust recommendations accordingly
- **Security matters** — If there's a CVE or known vulnerability, flag it prominently and suggest prioritizing
- **Offer alternatives** — If a package is risky to update, offer to skip it or update cautiously
- **Lock files are essential** — Always ensure lock files are regenerated and committed
- **Test after updating** — Remind the user to run their test suite

## If the package manager is unfamiliar

Search for "[language/ecosystem] how to update dependencies" and follow the official docs. Most ecosystems have a standard workflow:

1. List outdated packages
2. Review changes
3. Update version specifiers
4. Regenerate lock files
5. Test

If you get stuck on a specific command, search more narrowly: "[package manager] outdated command" or "[language] dependency resolver conflicts"
