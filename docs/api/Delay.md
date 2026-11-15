Delay: retry delay strategies for `Task.withRetries`.

A `Strategy` is an iterator: each call returns the next delay in seconds, or nil when no retries remain. Every
constructor returns a fresh strategy; the infinite ones are usually capped with `Delay.take`. Delays are in seconds (as
`C_Timer.After` and Lune's `task.delay` take them), not true-myth's milliseconds.

Pure: no clock and no randomness of its own (`Delay.jitter` takes the random source as an argument).

Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
