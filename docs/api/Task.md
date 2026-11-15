Task: an asynchronous operation that resolves with a value or rejects with a typed reason, never raises.

A `Task<T, E>` starts `Pending` and settles exactly once, to `Resolved<T>` or `Rejected<E>`; later settlements are
ignored. Read its current state from `task.state` (read-only). Callbacks registered with `Task.whenSettled` (and every
combinator) run synchronously, in registration order, when the task settles; on an already settled task they run at
once. No event loop or scheduler is needed, which is what makes `Task` work unchanged in a WoW addon (Lua 5.1) and in
Lune.

`Task.async(body)` runs `body` as a coroutine in which `Task.await(task)` suspends until `task` settles and returns its
`Result`. Time-based helpers (`timer`, `timeout`, `withRetries`) take a `Schedule` so the host supplies the clock:
`C_Timer.After` in WoW, `task.delay` in Lune.

Functions that relate a task's payload to a callback or return value take the task's whole type as `K` and read its
payload types with `ValueOf<K>` and `ReasonOf<K>`, for the reason given in Result.luau.

Differences from true-myth: no Promises (Lua has none), so there is no `fromPromise`/`toPromise`; `async`/`await`
replace `await task`; `withRetries` stops early through a typed `shouldRetry` option instead of a `StopRetrying`
sentinel; delays are in seconds.

Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
