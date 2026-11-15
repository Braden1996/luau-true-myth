Wraps a function that may raise into one that returns a `Result`: `Ok` of its first return value, or
`Err(onError(raised))`.
