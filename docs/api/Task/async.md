Runs `body` as a coroutine in which `Task.await` may suspend. The task settles with the `Result` that `body` returns:
`Ok` resolves, `Err` rejects. An error raised by `body` is a defect and propagates.

Lua 5.1 (WoW) cannot suspend a coroutine across `pcall` or a metamethod, so do not `Task.await` inside one.
