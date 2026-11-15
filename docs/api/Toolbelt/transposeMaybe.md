`Maybe<Result<T, E>>` to `Result<Maybe<T>, E>`: `Just(Ok(x))` is `Ok(Just(x))`, `Just(Err(e))` is `Err(e)`, `Nothing` is
`Ok(Nothing)`.
