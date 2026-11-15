# Design

How luau-true-myth differs from [true-myth](https://github.com/true-myth/true-myth), and why. The rules it follows
are in the [strict Luau guide](strict-luau-guide.md).

## Data, not classes

true-myth's `Maybe`, `Result` and `Task` are class instances with methods. Here they are plain read-only tables
with a `kind` tag, and every operation is a module function:

| true-myth                       | luau-true-myth                                |
| ------------------------------- | --------------------------------------------- |
| `result.map(f)`                 | `Result.map(result, f)`                       |
| `result.isOk` (narrows)         | `result.kind == "Ok"` (narrows)               |
| `result.value` after narrowing  | `result.value` after narrowing                |
| `Maybe.of(x)`                   | `Maybe.of(x)`                                 |
| `result.variant === Variant.Ok` | `result.kind == "Ok"`                         |
| `toJSON` / `fromJSON`           | not needed: the values are already plain data |

Reasons:

- **Serialisation.** World of Warcraft SavedVariables and JSON drop metatables. A plain table survives both and can
  be compared with `Result.equals` after a reload.
- **Typing.** Metatable-based classes need `typeof(setmetatable(...))` tricks in Luau, and their methods cannot be
  generic per call. Module functions infer cleanly on the new solver.
- **Narrowing.** `if r.kind == "Ok"` refines the union, so the value is reachable only on the `Ok` branch.

## Variant-specific type parameters

`Ok<T>` has no error type and `Err<E>` no value type. `Result<T, E> = Ok<T> | Err<E>`. So `Result.ok(1)` is an
`Ok<number>`, assignable to every `Result<number, E>` without an annotation. true-myth's `Result.ok<number, string>(1)`
needs both parameters because its classes carry both. The same holds for `Just<T> | Nothing` and Task states.

## Whole-type generics with type functions

A function such as `map` takes the result's whole type `R` and reads its payload types with type functions:

```luau
function Result.map<R, U>(result: R, f: (value: OkOf<R>) -> U): Result<U, ErrOf<R>>
```

The obvious signature, `map<T, U, E>(result: Result<T, E>, f: (T) -> U)`, does not work on Luau's new solver
(luau-lsp 1.70.1). The solver relates the argument's `Err` variant to the parameter's `Ok<T>` and records `nil` as a
lower bound of `T`. Then every annotated callback, such as `function(n: number)`, fails to instantiate. Inferring `R`
whole avoids decomposing the union, and `OkOf<R>`/`ErrOf<R>` read the payloads back out. The type functions also
reject anything that is not a Result with a clear message.

A side effect is that error types compose: `Result.andThen` returns `Result<OkOf<S>, ErrOf<R> | ErrOf<S>>`, so a
chain's error type is the union of its steps' errors, without annotations.

## No currying, data first

true-myth offers curried forms (`map(f)(result)`) for pipelines. Luau has no pipe operator, and overloads that
return functions make inference worse. Every function takes its data first: `Result.map(result, f)`.

## `and_`, `or_`

`and` and `or` are Lua keywords, so `Result.and` is a syntax error. The trailing underscore is the usual Lua
convention.

## Task without promises

Lua has no promises or event loop, and WoW addons run in a host that owns the clock. So:

- A `Task` settles through `resolve`/`reject` callbacks. Continuations run synchronously when it settles, in
  registration order.
- `Task.async(body)` runs `body` as a coroutine. `Task.await(task)` suspends it and returns a `Result`, which
  replaces `await task` in TypeScript.
- Time comes from outside: `timer`, `timeout` and `withRetries` take a `Schedule` (`C_Timer.After` in WoW,
  `task.delay` in Lune).
- Delays are in seconds, which both hosts use, not milliseconds.
- `withRetries` stops early through a typed `shouldRetry(reason, status)` option. true-myth uses a `StopRetrying`
  error sentinel, which would put an untyped value in the rejection type.
- There is no `fromPromise`, `toPromise`, `safelyTry` over promises, or `Task.fromUnsafePromise`.

## Not ported

| true-myth                          | Why not                                                                      |
| ---------------------------------- | ---------------------------------------------------------------------------- |
| `ap`                               | It applies curried functions, and the library has no currying.               |
| `Unit`                             | Use `Result<nil, E>`: `Result.ok(nil)` is a success with no payload.         |
| `orThrow`, `orThrowWith`, `unwrap` | Raising for an expected failure goes against the library's purpose.          |
| `toJSON`, `fromJSON`, `inspect`    | Values are already plain data. `toString` renders them.                      |
| `Maybe.property` / typed `get`     | Generic keys widen to `string`. `Maybe.get` covers maps.                     |
| Standard Schema integration        | TypeScript-ecosystem specific.                                               |
| ESLint plugin (`must-use`)         | No equivalent lint host. A discarded `Result` is caught in review.           |
| Tuple-typed `all`/`any`            | Luau has no variadic tuple types. The list versions take a homogeneous list. |

## Additions

- `Result.partition`, `Maybe.values`, `Maybe.filter`: common in Luau code that processes lists.
- `Exhaustive.casesHandled`: exhaustiveness for any tagged union. Luau does not check `if` chains on its own.
- `Task.peek`, `Task.whenSettled`: inspect or observe a task without `async`.
- `Delay.take`, `Delay.none`, `Delay.linear`: true-myth composes strategies with iterator helpers that Lua lacks.
