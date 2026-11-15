--!strict
local Harness = require("../harness")
local Types = require("../../src/TrueMyth") -- types only: the spec uses `lib`, the build under test

type Lib = typeof(Types)
type Task<T, E> = Types.Task<T, E>
type Result<T, E> = Types.Result<T, E>

return function(lib: Lib, t: Harness.T)
	local Task, Result, Delay = lib.Task, lib.Result, lib.Delay

	local function deferred(): (Task<number, string>, (number) -> (), (string) -> ())
		local d = Task.withResolvers() :: Types.Deferred<number, string>
		return d.task, d.resolve, d.reject
	end

	t.test("resolve, reject and the state predicates", function()
		local good = Task.resolve(1)
		t.equal(good.state, { kind = "Resolved", value = 1 })
		t.equal(Task.isResolved(good), true)
		t.equal(Task.isPending(good), false)
		local bad = Task.reject("e")
		t.equal(bad.state, { kind = "Rejected", reason = "e" })
		t.equal(Task.isRejected(bad), true)
		t.equal(Task.isRejected(good), false)
	end)

	t.test("new settles once, first settlement wins", function()
		local resolveLater: ((number) -> ())? = nil
		local task: Task<number, string> = Task.new(function(resolve: (number) -> (), reject: (string) -> ())
			resolveLater = resolve
			reject("first")
		end)
		local resolve = resolveLater
		if resolve == nil then
			error("the executor did not run", 0)
		end
		resolve(2)
		t.equal(task.state, { kind = "Rejected", reason = "first" })
	end)

	t.test("withResolvers settles later and notifies waiters in order", function()
		local task, resolve = deferred()
		local log: { string } = {}
		Task.whenSettled(task, function(result: Result<number, string>)
			table.insert(log, "a " .. Result.toString(result))
		end)
		Task.whenSettled(task, function(_: Result<number, string>)
			table.insert(log, "b")
		end)
		t.equal(Task.isPending(task), true)
		t.equal(Task.peek(task), nil)
		resolve(3)
		resolve(4)
		t.equal(log, { "a Ok(3)", "b" })
		t.equal(Task.peek(task), Result.ok(3))
		Task.whenSettled(task, function(_: Result<number, string>)
			table.insert(log, "late")
		end)
		t.equal(log[3], "late", "a settled task calls back at once")
	end)

	t.test("fromResult", function()
		t.equal(Task.fromResult(Result.ok(1)).state, { kind = "Resolved", value = 1 })
		t.equal(Task.fromResult(Result.err("e")).state, { kind = "Rejected", reason = "e" })
	end)

	t.test("map and mapRejected", function()
		local task, resolve = deferred()
		local doubled = Task.map(task, function(n: number): number
			return n * 2
		end)
		t.equal(Task.isPending(doubled), true)
		resolve(2)
		t.equal(Task.peek(doubled), Result.ok(4))
		t.equal(Task.peek(Task.map(Task.reject("e"), tostring)), Result.err("e"))
		t.equal(Task.peek(Task.mapRejected(Task.reject("e"), string.upper)), Result.err("E"))
		t.equal(Task.peek(Task.mapRejected(Task.resolve(1), string.upper)), Result.ok(1))
	end)

	t.test("andThen and orElse follow the returned task", function()
		local inner, resolveInner = deferred()
		local outer = Task.andThen(Task.resolve(1), function(_: number): Task<number, string>
			return inner
		end)
		t.equal(Task.isPending(outer), true)
		resolveInner(5)
		t.equal(Task.peek(outer), Result.ok(5))
		local skipped = Task.andThen(Task.reject("e"), function(n: number): Task<number, string>
			return Task.resolve(n)
		end)
		t.equal(Task.peek(skipped), Result.err("e"))
		local recovered = Task.orElse(Task.reject("e"), function(reason: string): Task<number, boolean>
			return if reason == "e" then Task.resolve(0) else Task.reject(false)
		end)
		t.equal(Task.peek(recovered), Result.ok(0))
		local failedAgain = Task.orElse(Task.reject("x"), function(_: string): Task<number, boolean>
			return Task.reject(false)
		end)
		t.equal(Task.peek(failedAgain), Result.err(false))
		t.equal(
			Task.peek(Task.orElse(Task.resolve(1), function(_: string): Task<number, boolean>
				return Task.reject(true)
			end)),
			Result.ok(1)
		)
	end)

	t.test("and_ and or_", function()
		t.equal(Task.peek(Task.and_(Task.resolve(1), Task.resolve("b"))), Result.ok("b"))
		t.equal(Task.peek(Task.and_(Task.reject("e"), Task.resolve("b"))), Result.err("e"))
		t.equal(Task.peek(Task.or_(Task.resolve(1), Task.resolve(2))), Result.ok(1))
		t.equal(Task.peek(Task.or_(Task.reject("e"), Task.reject(false))), Result.err(false))
	end)

	t.test("match and toResult never reject", function()
		local matcher = {
			Resolved = function(n: number): string
				return "resolved " .. n
			end,
			Rejected = function(e: string): string
				return "rejected " .. e
			end,
		}
		t.equal(Task.peek(Task.match(Task.resolve(1), matcher)), Result.ok("resolved 1"))
		t.equal(Task.peek(Task.match(Task.reject("e"), matcher)), Result.ok("rejected e"))
		t.equal(Task.peek(Task.toResult(Task.reject("e"))), Result.ok(Result.err("e")))
	end)

	t.test("inspect and inspectRejected", function()
		local log: { string } = {}
		local task, _, reject = deferred()
		t.same(
			Task.inspect(task, function(n: number)
				table.insert(log, "value " .. n)
			end),
			task
		)
		t.same(
			Task.inspectRejected(task, function(e: string)
				table.insert(log, "reason " .. e)
			end),
			task
		)
		reject("e")
		Task.inspect(Task.resolve(2), function(n: number)
			table.insert(log, "value " .. n)
		end)
		t.equal(log, { "reason e", "value 2" })
	end)

	t.test("all resolves in input order and rejects on the first rejection", function()
		local a, resolveA = deferred()
		local b, resolveB = deferred()
		local both = Task.all({ a, b })
		resolveB(2)
		t.equal(Task.isPending(both), true)
		resolveA(1)
		t.equal(Task.peek(both), Result.ok({ 1, 2 }))
		local c, _, rejectC = deferred()
		local failed = Task.all({ c, Task.resolve(1) })
		rejectC("e")
		t.equal(Task.peek(failed), Result.err("e"))
		t.equal(Task.peek(Task.all({} :: { Task<number, string> })), Result.ok({}))
	end)

	t.test("allSettled collects every result", function()
		local a, _, rejectA = deferred()
		local settled = Task.allSettled({ a, Task.resolve(2) })
		t.equal(Task.isPending(settled), true)
		rejectA("e")
		t.equal(Task.peek(settled), Result.ok({ Result.err("e"), Result.ok(2) }))
		t.equal(Task.peek(Task.allSettled({} :: { Task<number, string> })), Result.ok({}))
	end)

	t.test("any resolves with the first resolution or rejects with every reason", function()
		local a, _, rejectA = deferred()
		local b, resolveB = deferred()
		local first = Task.any({ a, b })
		rejectA("a")
		t.equal(Task.isPending(first), true)
		resolveB(2)
		t.equal(Task.peek(first), Result.ok(2))
		local none = Task.any({ Task.reject("x"), Task.reject("y") })
		t.equal(Task.peek(none), Result.err({ "x", "y" }))
		t.equal(Task.peek(Task.any({} :: { Task<number, string> })), Result.err({}))
	end)

	t.test("race settles like the first to settle", function()
		local a, _, rejectA = deferred()
		local b, resolveB = deferred()
		local winner = Task.race({ a, b })
		rejectA("a")
		resolveB(2)
		t.equal(Task.peek(winner), Result.err("a"))
		t.equal(Task.isPending(Task.race({} :: { Task<number, string> })), true)
	end)

	t.test("async and await", function()
		local a, resolveA = deferred()
		local b, _, rejectB = deferred()
		local steps: { string } = {}
		local sum = Task.async(function(): Result<number, string>
			table.insert(steps, "start")
			local first = Task.await(a)
			if first.kind == "Err" then
				return first
			end
			table.insert(steps, "got a")
			local second = Task.await(b)
			if second.kind == "Err" then
				return Result.err("b failed: " .. second.error)
			end
			return Result.ok(first.value + second.value)
		end)
		t.equal(steps, { "start" }, "the body runs at once and suspends")
		resolveA(1)
		t.equal(steps, { "start", "got a" })
		t.equal(Task.isPending(sum), true)
		rejectB("boom")
		t.equal(Task.peek(sum), Result.err("b failed: boom"))
		local immediate = Task.async(function(): Result<number, string>
			local r = Task.await(Task.resolve(2))
			return if r.kind == "Ok" then Result.ok(r.value * 10) else r
		end)
		t.equal(Task.peek(immediate), Result.ok(20), "awaiting a settled task does not suspend")
	end)

	t.test("await outside async is a defect", function()
		local task = deferred()
		t.raises(function()
			Task.await(task)
		end, "Task.await: called outside Task.async")
	end)

	t.test("an error raised in async is a defect and propagates", function()
		t.raises(function()
			Task.async(function(): Result<number, string>
				error("broken invariant", 0)
			end)
		end, "broken invariant")
	end)

	t.test("timer and timeout use the injected schedule", function()
		local clock = Harness.fakeClock()
		local timer = Task.timer(2, clock.schedule)
		clock.advance(1)
		t.equal(Task.isPending(timer), true)
		clock.advance(1)
		t.equal(Task.peek(timer), Result.ok(2))

		local slow, resolveSlow = deferred()
		local limited = Task.timeout(slow, 5, clock.schedule)
		clock.advance(5)
		resolveSlow(1)
		t.equal(Task.peek(limited), Result.err({ kind = "Timeout", seconds = 5 }))

		local fast, resolveFast = deferred()
		local inTime = Task.timeout(fast, 5, clock.schedule)
		resolveFast(1)
		clock.advance(5)
		t.equal(Task.peek(inTime), Result.ok(1))
		t.equal(Task.peek(Task.timeout(Task.reject("e"), 5, clock.schedule)), Result.err("e"))
	end)

	t.test("withRetries retries until success", function()
		local statuses: { { count: number, elapsed: number } } = {}
		local task = Task.withRetries(function(status: Types.RetryStatus): Task<string, string>
			table.insert(statuses, { count = status.count, elapsed = status.elapsed })
			return if status.count < 2 then Task.reject("try " .. status.count) else Task.resolve("done")
		end)
		t.equal(Task.peek(task), Result.ok("done"))
		t.equal(statuses, { { count = 0, elapsed = 0 }, { count = 1, elapsed = 0 }, { count = 2, elapsed = 0 } })
	end)

	t.test("withRetries gives up when the strategy runs out", function()
		local clock = Harness.fakeClock()
		local task = Task.withRetries(function(status: Types.RetryStatus): Task<string, string>
			return Task.reject("fail " .. status.count)
		end, { strategy = Delay.take(Delay.exponential(), 2), schedule = clock.schedule })
		t.equal(Task.isPending(task), true)
		clock.advance(1)
		t.equal(Task.isPending(task), true)
		clock.advance(2)
		t.equal(
			Task.peek(task),
			Result.err({ kind = "RetryFailed", tries = 3, elapsed = 3, rejections = { "fail 0", "fail 1", "fail 2" } })
		)
	end)

	t.test("withRetries stops when shouldRetry says so", function()
		local attempts = 0
		local task = Task.withRetries(function(_: Types.RetryStatus): Task<string, string>
			attempts += 1
			return Task.reject(if attempts == 2 then "fatal" else "transient")
		end, {
			strategy = Delay.immediate(),
			shouldRetry = function(reason: string, _: Types.RetryStatus): boolean
				return reason ~= "fatal"
			end,
		})
		t.equal(attempts, 2)
		t.equal(
			Task.peek(task),
			Result.err({ kind = "RetryFailed", tries = 2, elapsed = 0, rejections = { "transient", "fatal" } })
		)
	end)

	t.test("withRetries without a schedule cannot wait", function()
		t.raises(function()
			Task.withRetries(function(_: Types.RetryStatus): Task<string, string>
				return Task.reject("e")
			end, { strategy = Delay.fixed(1) })
		end, "needs options.schedule")
	end)
end
