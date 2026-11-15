Result: the outcome of an operation that can fail, as a value.

A `Result<T, E>` is either `Ok<T>` (`{ kind = "Ok", value = T }`) or `Err<E>` (`{ kind = "Err", error = E }`). Both are
plain, read-only tables: no metatables, so they survive serialisation (WoW SavedVariables, JSON) and compare
structurally with `Result.equals`. Narrow with `if r.kind == "Ok" then ... r.value ... end`.

`Ok<T>` carries no error type and `Err<E>` no value type, so `Result.ok(1)` is assignable to any `Result<number, E>`
without annotations.

Functions that relate a result's payload to a callback, default or return value take the result's whole type as `R` and
read its payload types with `OkOf<R>` and `ErrOf<R>` (type functions). Luau's new solver, given `Result<T, E>` as a
parameter, infers `T` from the `Err` variant too (as nil) and then rejects annotated callbacks such as `function(n:
number)`; inferring the whole type avoids that. See docs/design.md.

Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
