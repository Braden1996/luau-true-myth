`Result<Maybe<T>, E>` to `Maybe<Result<T, E>>`: `Ok(Just(x))` is `Just(Ok(x))`, `Ok(Nothing)` is `Nothing`, `Err(e)` is
`Just(Err(e))`.
