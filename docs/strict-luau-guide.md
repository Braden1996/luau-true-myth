# Strict Luau guide

Rules for Luau that is strict and hard to misuse, and the tooling that enforces each one. They adapt Dillon
Mulroy's TypeScript coding standards ([gist](https://gist.github.com/dmmulroy/9c80f1f499b031aa0b6525b5d9ae25f0),
expanded in the `coding-standards` skill of [dmmulroy/skills](https://github.com/dmmulroy/skills)) to Luau on the
**new type solver**. Everything here was verified against luau-lsp 1.70.1, StyLua 2.6.0, selene 0.32.0 and darklua
0.19.0 while building this library. Where the solver could not do something, the guide says so and gives the
workaround that does work.

The guide is written for code compiled to Lua 5.1 (World of Warcraft addons, via darklua) as well as code run by Lune.
Rules marked **5.1** matter only for code that ships to Lua 5.1.

## Contents

- [The source rules in one paragraph](#the-source-rules-in-one-paragraph)
- [Enforcement at a glance](#enforcement-at-a-glance)
- [1. Type checker settings](#1-type-checker-settings)
- [2. Errors are values](#2-errors-are-values)
- [3. Raise only for defects](#3-raise-only-for-defects)
- [4. Tagged unions and exhaustive matching](#4-tagged-unions-and-exhaustive-matching)
- [5. No `any`, no unexplained casts, no forced non-nil](#5-no-any-no-unexplained-casts-no-forced-non-nil)
- [6. Parse at the boundary](#6-parse-at-the-boundary)
- [7. Branded types: what Luau can and cannot do](#7-branded-types-what-luau-can-and-cannot-do)
- [8. Immutability](#8-immutability)
- [9. Illegal states and boolean blindness](#9-illegal-states-and-boolean-blindness)
- [10. Generics that the new solver infers well](#10-generics-that-the-new-solver-infers-well)
- [11. Modules, classes and dependencies](#11-modules-classes-and-dependencies)
- [12. Lua 5.1 targets](#12-lua-51-targets)
- [13. Tests](#13-tests)
- [14. Documentation comments](#14-documentation-comments)
- [15. CI gates](#15-ci-gates)
- [Solver findings](#solver-findings)

## The source rules in one paragraph

Every known failure is part of a function's return type as a tagged error value; throwing is reserved for defects.
Untrusted input is parsed once, at the boundary, into precise domain types; inner code never re-validates.
Lifecycles are tagged unions, not bags of optional fields and booleans. Every union is matched exhaustively, ending in
a `never` check. There is no `any`, no non-null assertion and no `as` cast except at a few documented seams, each
of which the source rules justify with a `SAFETY:` comment (this repository uses a function name instead, see section 5). Data is read-only by default. Dependencies are small
structural "ports" passed in explicitly; there are no module mocks, no barrels and no vague module names. Tests go
through real entry points and assert observable results. The TypeScript sources enforce this with `strict`
compiler flags plus conventions; this guide adds tooling wherever Luau has something to enforce it with.

## Enforcement at a glance

| Rule                                    | Enforced by                                                                            |
| --------------------------------------- | -------------------------------------------------------------------------------------- |
| Strict mode everywhere                  | `.luaurc` `languageMode: strict`, `--!strict` header (custom lint)                     |
| New solver                              | `--flag:LuauSolverV2=true` in CI; editor fflag settings                                |
| No `--!nonstrict` / `--!nocheck`        | custom lint (`scripts/lint.luau`)                                                      |
| `:: any` only in `unchecked…` functions | custom lint                                                                            |
| No comments: names and tests instead    | custom lint (`--!strict` and fixture `-- expect-error:` markers excepted)              |
| No generic local helpers in `src/`      | custom lint (they trip luau-lsp 1.70.1, see section 10)                                |
| Exhaustive matching                     | `casesHandled(value: never)`: luau-lsp error when a variant is unhandled               |
| Read-only data                          | `read` property modifiers: luau-lsp error on write                                     |
| Errors as values                        | `Result<T, E>` return types; review; `selene` cannot detect `error()` misuse           |
| No Luau-only library calls in 5.1 code  | custom lint, `selene` with `std = "lua51"` on the darklua output, Lua 5.1-only runtime |
| Output is valid Lua 5.1                 | `stylua --syntax Lua51` on the darklua output                                          |
| Formatting                              | StyLua (Luau), dprint (Markdown/JSON/YAML/TOML)                                        |
| Expected type errors stay expected      | negative fixtures compared to exact luau-lsp output                                    |
| Every public function tested            | API coverage check in the test runner                                                  |
| Workflows pinned and safe               | actionlint, zizmor, actions pinned by SHA, Dependabot                                  |
| The gate is the gate                    | `moon run :check` runs cold in CI; lefthook runs it pre-push                           |

## 1. Type checker settings

**Source rule:** `strict: true`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`,
`noFallthroughCasesInSwitch`.

**Luau:**

- `.luaurc` sets `"languageMode": "strict"`, and every file still starts with `--!strict`, so a file copied elsewhere
  keeps its mode. A custom lint fails on a missing header and on `--!nonstrict` or `--!nocheck`.
- Use the **new solver** everywhere: `luau-lsp analyze --flag:LuauSolverV2=true`. In VS Code set
  `"luau-lsp.fflags.enableNewSolver": true`. In Zed set `lsp.luau-lsp.settings.fflags.enable_new_solver`. The old
  solver ignores `read` modifiers, type functions and much of the refinement this guide relies on.
- Luau already treats `t[k]` on a `{ [K]: V }` map as `V`, not `V?`, the way TypeScript does without
  `noUncheckedIndexedAccess`. There is no flag to change that, so **read maps through a function that returns
  `Maybe<V>`** (`Maybe.get(map, key)`) or annotate the local as `V?`.
- There is no `switch` statement in Luau, so `noFallthroughCasesInSwitch` has nothing to apply to. Exhaustiveness
  is covered in section 4.
- Pin the analyzer (`luau-lsp` in `mise.toml`): new-solver behaviour changes between releases.

## 2. Errors are values

**Source rule:** every known failure (domain, parse, I/O, integration, configuration) appears in the return type as a
tagged error, even when the immediate caller cannot recover. A rejected promise counts as a throw. Use one result
strategy per codebase.

**Luau:**

- Return `Result<T, E>` (this library) for every operation that can fail in a known way. `E` is a union of tagged
  error tables, never a bare string:

  ```luau
  type NotFound = { read kind: "NotFound", read id: number }
  type Invalid = { read kind: "Invalid", read reason: string }
  type LookupError = NotFound | Invalid

  local function findQuest(id: number): Result<Quest, LookupError>
  ```

- Keep error unions precise at module boundaries. A broad `AppError` belongs only near the entry point that renders
  or logs it.
- `Result.andThen` and `Task.andThen` add error types up (`ErrOf<R> | ErrOf<S>`), so a chain's error type lists
  exactly the failures it can produce.
- Asynchronous work returns `Task<T, E>` (rejections typed), never a callback that might raise.
- Code that raises (WoW APIs, `string.format` with bad input, third-party Lua) is wrapped at the boundary with
  `Result.tryOrElse(parseRaised, f)` or `Result.safe(f, parseRaised)`. `parseRaised` turns the raised value into a
  tagged error.
- One strategy: do not mix `Result` with `ok, err` multiple returns or `nil, "message"` returns in new code.
  Translate those at the boundary.

**Enforcement:** the types. A function declared to return `Result<T, E>` cannot return a bare value or a wrongly
typed error. That is checked in this repository's negative fixtures (`tests/fail/result.luau`). No linter can tell a
"known failure" `error()` from a defect, so that part stays a review rule (see section 3).

## 3. Raise only for defects

**Source rule:** throw only when correct execution is impossible: a violated invariant, an impossible branch, a
temporary not-yet-implemented path. Helpers: `casesHandled`, `shouldNeverHappen`, `notYetImplemented`.

**Luau:**

- `error()` is for defects only: a nil passed to `Maybe.just`, `Task.await` outside `Task.async`, an unhandled case
  reached at run time.
- End every exhaustive chain with `Exhaustive.casesHandled(value)`. It is a compile-time check and raises if reached.
- Raise only for defects, and cover each one with a test that asserts the message (`t.raises`). Expected failures belong
  in the return type.
- **5.1:** WoW's Lua 5.1 cannot yield across `pcall`, so never `Task.await` inside a protected call.

## 4. Tagged unions and exhaustive matching

**Source rule:** discriminated unions with a literal tag. Exhaustive handling through a `never`-typed helper. Tag
helpers `Tags<E>`, `ExtractTag<E, K>`.

**Luau:**

- Discriminate on a string-singleton field. This repository uses **`kind`** throughout (`Ok`/`Err`,
  `Just`/`Nothing`, `Pending`/`Resolved`/`Rejected`). Pick one name per codebase.
- Narrow with `if x.kind == "Ok" then ... end`. Reading a variant-only field without narrowing is an error: "Key
  'value' is missing from 'Err<string>'".
- **Exhaustiveness** is not automatic. Luau does not warn when an `if`/`elseif` chain misses a variant, and does not
  flag `x.kind == "Typo"`. End the chain with a function that takes `never`:

  ```luau
  local function describe(e: LookupError): string
  	if e.kind == "NotFound" then
  		return "missing " .. e.id
  	elseif e.kind == "Invalid" then
  		return e.reason
  	end
  	return Exhaustive.casesHandled(e) -- error if a variant is missing: "Expected this to be unreachable, but got 'Timeout'"
  end
  ```

- Matcher tables (`Result.match(r, { Ok = ..., Err = ... })`) are exhaustive by construction: a missing handler is
  "missing field 'Err'".
- Luau has no user-defined type guards (`x is T`). Predicates such as `Result.isOk` return `boolean` and do not
  narrow, so use them for filtering and compare the tag to narrow.
- Union literal tables sometimes need a cast to the variant: `{ kind = "Invalid", reason = "..." } :: Invalid`.
  This upcast is checked, so it is allowed anywhere.

## 5. No `any`, no unexplained casts, no forced non-nil

**Source rule:** avoid `any`, `as` casts and the non-null `!`. Every remaining cast needs a Rust-style `// SAFETY:`
comment. `as const` is fine. This repository replaces the comment with a name (see below).

**Luau:**

- `unknown` for values of unknown type, then narrow with `type(x) == "table"` or parse (section 6). `any` turns off
  checking for everything it touches.
- `:: T` is a checked cast only when one type is a subtype of the other. `:: any` is the escape hatch, and it may only
  appear inside a small function whose name starts with `unchecked` and says what it assumes:
  `uncheckedJustOfNonNil`, `uncheckedRecordOf`, `uncheckedRequireSpec`. The custom lint enforces this. The name
  replaces a `SAFETY:` comment, and callers read the assumption at every call site.
- Acceptable `:: any` seams, all present in this library: viewing a generic parameter through its runtime shape
  after a type function has validated it; one private non-generic representation (section 10); `setmetatable`
  results.
- Luau has no `!` operator. Instead of asserting non-nil, branch:
  `local x = maybeX; if x == nil then return Result.err(...) end`. `assert(x)` narrows too, but it raises, so use it
  only for invariants (section 3).
- **Return-only generics.** Luau cannot infer a generic that appears only in the result
  (`Task.withResolvers<T, E>()`), and it infers `unknown` even from an annotated local. Name the types with a cast,
  which is checked here: `Task.withResolvers() :: Deferred<number, string>`. Explicit instantiation
  (`f<<number>>()`) type-checks and darklua accepts it, but StyLua 2.6.0 cannot parse it, so do not use it yet.

## 6. Parse at the boundary

**Source rule:** parse, don't validate. Untrusted input becomes a domain type as early as possible, through
`parseX(input): Result<X, ParseXError>`. Avoid `validateX`. Raw rows and transport shapes never reach the core.

**Luau:**

- Untrusted input includes event payloads typed loosely by the host, SavedVariables (players and other addon
  versions write them), slash-command text, `C_*` results the definitions leave `unknown`, and JSON in Lune.
- Write `parseX(raw: unknown): Result<X, ParseError>` and return precise types. After that, code takes `X`, never
  `unknown` or `{ [string]: any }`.
- Naming follows the source rules. `parseX` takes untrusted input. `makeX` builds from already-typed parts. `isX`
  returns `boolean` (no narrowing, see section 4).
- SavedVariables especially: parse the whole table on `ADDON_LOADED` into a versioned domain type, migrating old
  versions, and write it back from domain values only.

## 7. Branded types: what Luau can and cannot do

**Source rule:** `Brand<string, "EmailAddress">` for IDs, units and refined values, constructed only by a parser or
smart constructor, used when it prevents a realistic mistake.

**Luau:** Luau types are structural and have no nominal brand for primitives. `number & { __brand: "QuestId" }`
type-checks as a declaration, but no `number` value can inhabit it without `:: any`. The options that work:

- **Wrapper tables** for values that cross module boundaries, where mixing them up is a real risk:
  `type QuestId = { read kind: "QuestId", read value: number }`. They are cheap and distinct (`QuestId` is not
  `NpcId`), and they serialise as plain tables.
- **Phantom string-singleton fields** on records you already pass around (`read unit: "seconds"`), so two shapes
  that differ only in meaning stop being interchangeable.
- **Named aliases** (`type Seconds = number`) document intent but are _not_ checked. Do not rely on them for safety.

## 8. Immutability

**Source rule:** `readonly` fields and `ReadonlyArray<T>` by default; mutation only in local imperative code,
builders or adapters behind a precise interface.

**Luau:**

- Use the `read` property modifier: `{ read kind: "Ok", read value: T }`. A write is an error: "Property value of
  table 'Ok<number>' is read-only". `read` types are covariant, so `Ok<number>` is assignable to `Ok<number?>`.
- Read-only arrays: take `{ read [number]: T }` when a function only reads a list. A plain `{ T }` argument is
  accepted, and a write is an error ("Property indexer of table ... is read-only"). Return fresh arrays rather than
  mutating arguments.
- Where state must change (this library's `Task`), keep a private mutable type and export a read-only view
  (`{ read state: State<T, E> }`).
- Do not use `table.freeze` in code that ships to Lua 5.1: it does not exist there (**5.1**), and the solver widens
  frozen literals' string singletons to `string`.

## 9. Illegal states and boolean blindness

**Source rule:** lifecycles as tagged unions instead of flag bags. No behaviour-controlling boolean parameters. No
`Partial<T>` inputs. Push optionality outward.

**Luau:**

- `Pending | Resolved<T> | Rejected<E>`, not `{ done: boolean, value: T?, err: E? }`.
- Use option tables with literal unions instead of boolean flags: `retry(op, { strategy = Delay.exponential() })`,
  `fetch(id, { cache = "skip" })`.
- Functions that need a value take `T`, not `T?`. Branch or parse before the call. Reserve `?` for real absence and
  prefer `Maybe<T>` when absence must be handled explicitly.

## 10. Generics that the new solver infers well

This section has no TypeScript counterpart. It records what luau-lsp 1.70.1's new solver does with tagged-union
generics, and how this library's API is shaped around it.

- **Put each variant's type parameters only on that variant.** `Ok<T>` and `Err<E>`, then
  `Result<T, E> = Ok<T> | Err<E>`. Then `Result.ok(1)` is `Ok<number>` and is assignable to any `Result<number, E>`
  with no annotation. A constructor that has to invent the other parameter infers `unknown`.
- **Do not take `Result<T, E>` (or any tagged union) as a generic parameter when the same signature uses `T` in a
  callback or default.** The solver relates the argument's `Err` variant to the parameter's `Ok<T>` and records
  `nil` as a lower bound of `T` (from the missing `value` field). Then every annotated callback fails: "No valid
  instantiation could be inferred for generic type parameter T. It was expected to be at least number | nil and at
  most number". Swapping the union's order moves the bug to `E`.
- **Instead, infer the whole type and project it with a type function:**

  ```luau
  export type OkOf<R> = resultPayload<R, "Ok", "value"> -- a `type function` reading the variant's field
  function Result.map<R, U>(result: R, f: (value: OkOf<R>) -> U): Result<U, ErrOf<R>>
  ```

  This works for annotated and unannotated callbacks, across modules and inside other generic functions. The type
  function also validates its input and raises a clear error ("expected a Result, got ...") for anything else. Type
  functions are checked too: annotate them `(t: type): type`, and declare `types` for selene (`std = "luau+..."`).

- **Unannotated callbacks that use operators need annotations** (`function(n: number) return n + 1 end`). The solver
  asks for them: "Consider placing the following annotations on the arguments".
- **Generic local helpers called from closures inside generic functions break.** You get bogus "No valid
  instantiation" errors, and luau-lsp sometimes segfaults, when the module is checked as a dependency of another
  file. Keep private plumbing non-generic (one private type with `any` payloads, written only by typed public
  functions), and give generic helpers distinct parameter names.
- **Empty table literals have no element type.** `Result.all({})` is accepted, but its result is
  unusable: narrowing or assigning it fails with "expected a Result, got unknown". Write
  `Result.all({} :: { Result<number, string> })`.
- **`index<T, K>` cannot drive a typed `get`.** Generic `K` widens string literals to `string`. Type maps as
  `{ [K]: V }` instead.

## 11. Modules, classes and dependencies

**Source rule:** composition over inheritance. Domain modules are plain functions over immutable data, in the OCaml
style. Services get small structural ports by constructor injection. No module mocks. No barrels beyond one curated
prelude. No vague names (`utils`, `helpers`). Namespace imports. Inject `Clock`/`Random`.

**Luau:**

- A module is a table of functions over plain data: `Result.map(r, f)`, not `r:map(f)`. Metatable classes make
  values non-serialisable (WoW SavedVariables drop metatables) and are hard to type in the new solver. Use a class
  only for a stateful object with identity (a frame wrapper, a cache), never for a value.
- Require by path (`require("./Result")`) and keep the module name as the local (`local Result = ...`), which is the
  Luau form of `import * as Result`.
- Ports are structural table types defined beside their consumer, e.g.
  `type QuestLog = { read count: () -> number }`, passed in explicitly. For time, take a `Schedule` or `now` value
  (as `Task.timer` and `Delay.jitter` do) instead of calling `C_Timer`/`os.clock`/`math.random` inside logic.
- No vague module names. Name a module after its abstraction (`Delay`, `Toolbelt`), not `Utils`.

## 12. Lua 5.1 targets

Rules for code compiled by darklua and run by Lua 5.1 (WoW).

- Use darklua's rules `remove_types`, `remove_attribute`, `remove_compound_assignment`, `remove_continue`,
  `remove_floor_division`, `remove_if_expression`, `remove_interpolated_string` and `convert_luau_number`. Use
  `bundle` with `require_mode: "path"` to produce one file, because WoW has no `require`.
- **No Luau-only library functions** in shipped code: `table.clone`, `table.find`, `table.freeze`,
  `table.unpack`, `string.split`, `math.clamp`, `math.round`, `bit32`, `buffer`, `utf8` and others. darklua does not
  rewrite them. Enforced three ways: the custom lint (source), `selene` with `std = "lua51"` (output), and running
  the test suite against the bundle in a Lua 5.1-only environment.
- **No generalized iteration** (`for k, v in t do`) in shipped code. Lua 5.1 tries to call the table. Use
  `pairs`/`ipairs` (custom lint).
- Avoid string interpolation there too. darklua rewrites it, but the output is slow and unreadable.
- Validate the output with `stylua --syntax Lua51 --check -`, which fails on any surviving Luau syntax.
- Prepend licence notices to the bundle: darklua's `remove_comments` strips them.

## 13. Tests

**Source rule:** end-to-end tests through real entry points first, then integration, then property tests for pure
modules. Never `vi.mock`. Assert observable outcomes. Do not bypass parsers.

**Luau:**

- Write specs as `function(lib, t)` and run every spec against each build that users run. Here that is the Luau
  sources (Lune) and the darklua bundle in a Lua 5.1-only environment (WoW).
- Inject fakes through ports (a `FakeClock` implementing `Schedule`), not by patching globals.
- **Type tests are tests:** keep negative fixtures that must produce exact luau-lsp errors (`-- expect-error: ...`
  plus a recorded `.expected` file), and a positive fixture of idiomatic use that must produce none. They catch
  solver regressions when luau-lsp is bumped.
- Enforce API coverage: the runner records which public functions the specs call, and fails on any it missed.

## 14. Names and tests instead of comments

**Source rule:** JSDoc on every exported symbol.

**This repository departs from that rule:** there are no comments in Luau code. Comments drift from the code they
describe and nothing checks them. Instead:

- **Descriptive names.** A function or local says what it is (`delayBeforeNextAttempt`, `whenRecordSettles`,
  `uncheckedRawField`). If a block needs a comment to explain it, it becomes a named function.
- **Small functions.** Each does one thing, so its name is its documentation.
- **Colocated tests.** `src/Result.luau` sits next to `src/Result.spec.luau`. A test name states one behaviour
  ("andThen chains fallible steps"), and its body is a worked example that cannot go stale. Algorithms get a test
  per case.
- **Types as the reference.** The API reference is generated from the Luau types by
  [starlight-luau](https://github.com/Braden1996/starlight-luau), with each function's spec cases as examples.
- **Prose where prose belongs.** Explanations live in the guides and in `docs/`, not in source files.

The custom lint rejects any comment except the `--!strict` directive and the `-- expect-error:` markers of the
negative fixtures, which are test assertions.

## 15. CI gates

- One gate, `moon run :check`, run cold in CI (`MOON_CACHE=write`, no restored cache) and by the pre-push hook
  (`--affected`).
- Tools are pinned in `mise.toml` with checksums in `mise.lock`. GitHub Actions are pinned by commit SHA and bumped by
  Dependabot.
- actionlint and zizmor check the workflows, typos checks spelling, dprint formats non-Luau files, and lychee checks
  links offline.
- Generated files (the bundle, the banner) are checked for freshness, never edited by hand.

## Solver findings

Recorded while building this library, with luau-lsp 1.70.1 and `--flag:LuauSolverV2=true`.

| Finding                                                                                     | Workaround                                                 |
| ------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| A tagged-union parameter leaks a `nil` lower bound into its generics from the other variant | Infer the whole type, project with a type function         |
| Generic local helpers in closures inside generic functions: bogus errors, segfaults         | Non-generic private representation; distinct generic names |
| Return-only generics infer `unknown`, even with an annotated local                          | Checked cast `:: Deferred<number, string>`                 |
| `f<<T>>()` works in luau-lsp and darklua but not StyLua 2.6.0                               | Do not use it yet                                          |
| Disjoint tag comparisons (`x.kind == "Typo"`) are not reported                              | `casesHandled(value: never)` at the end of every chain     |
| `table.freeze({ kind = "X" })` widens `"X"` to `string`                                     | Annotate the local instead (and 5.1 has no `table.freeze`) |
| `index<T, K>` with generic `K` sees `string`, not the literal                               | Type maps as `{ [K]: V }`                                  |
| Operators on unannotated callback parameters ask for annotations                            | Annotate callback parameters                               |
