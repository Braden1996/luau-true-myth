Runs `f` in protected mode: `Ok(f())`, or `Err(onError(raised))` if `f` raised. `onError` parses the raised value (often
a string) into a typed error.
