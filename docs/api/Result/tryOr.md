Runs `f` in protected mode: `Ok(f())`, or `Err(error)` if `f` raised. Use it at the boundary with code that raises; the
raised value is discarded.
