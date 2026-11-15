Maybe: a value that may be absent, made explicit.

A `Maybe<T>` is either `Just<T>` (`{ kind = "Just", value = T }`) or `Nothing` (`{ kind = "Nothing" }`). Both are plain,
read-only tables: no metatables, so they survive serialisation and compare structurally with `Maybe.equals`. Narrow with
`if m.kind == "Just" then ... m.value ... end`.

`Nothing` carries no type parameter, so `Maybe.nothing()` is assignable to every `Maybe<T>`. A `Just` never holds nil:
`Maybe.of(value)` turns nil into `Nothing`, and `Maybe.just(nil)` is a defect (it raises).

Functions that relate a maybe's value to a callback, default or return value take the maybe's whole type as `M` and read
its value type with `ValueOf<M>`, for the reason given in Result.luau.

Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
