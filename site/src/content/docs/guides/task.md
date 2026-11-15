---
title: Task
description: Asynchronous results without promises, for WoW and Lune.
---

A `Task<T, E>` is an operation that settles once, to a value or to a typed rejection. It needs no event loop.
When a task settles, its callbacks run straight away, in the order they were registered. This is what lets the
same code run in a WoW addon and in Lune.

## Create

```luau
local Task = TrueMyth.Task

local function fetchQuest(id: number): Task<Quest, NotFound>
	return Task.new(function(resolve: (Quest) -> (), reject: (NotFound) -> ())
		-- call resolve or reject now or later, e.g. from an event handler
	end)
end

local done = Task.resolve(1)                                    -- Task<number, never>
local deferred = Task.withResolvers() :: Task.Deferred<number, string>
deferred.resolve(2)
```

Luau cannot infer types that appear only in a function's result, so `withResolvers` needs the cast to name
them.

## async and await

`Task.async(body)` runs `body` as a coroutine. Inside it, `Task.await(task)` suspends until the task settles and
returns its `Result`:

```luau
local summary = Task.async(function(): Result<string, NotFound>
	local quest = Task.await(fetchQuest(42))
	if quest.kind == "Err" then
		return quest
	end
	return Result.ok(quest.value.title)
end)
```

In Lua 5.1 (WoW) a coroutine cannot yield across `pcall`, so do not `Task.await` inside a protected call.

## Time: timeouts and retries

The host owns the clock, so time-based helpers take a `Schedule`, a function that runs a callback after a number
of seconds:

```luau
local schedule = C_Timer.After                                  -- WoW
local schedule = function(s: number, f: () -> ()) task.delay(s, f) end -- Lune

local limited = Task.timeout(fetchQuest(42), 5, schedule)       -- rejects with Timeout after 5 s
local retried = Task.withRetries(function(status: Task.RetryStatus): Task<Quest, NotFound>
	return fetchQuest(42)
end, {
	strategy = TrueMyth.Delay.take(TrueMyth.Delay.exponential({ from = 0.5 }), 4),
	schedule = schedule,
	shouldRetry = function(reason: NotFound, _: Task.RetryStatus): boolean
		return reason.id ~= 0
	end,
})
```

Delays are in seconds. `Delay` has fixed, linear, exponential, Fibonacci and jittered strategies, and `Delay.take`
caps any of them.

## Combine

`Task.all`, `Task.allSettled`, `Task.any` and `Task.race` combine lists of tasks. `Task.map`, `Task.andThen` and
`Task.orElse` chain them, and the rejection types add up the way `Result.andThen`'s error types do.

See the [Task API](../../api/task/) and the [Delay API](../../api/delay/).
