--!strict
--[[
	Task: an asynchronous operation that resolves with a value or rejects with a typed reason, never raises.

	A `Task<T, E>` starts `Pending` and settles exactly once, to `Resolved<T>` or `Rejected<E>`; later settlements
	are ignored. Read its current state from `task.state` (read-only). Callbacks registered with `Task.whenSettled`
	(and every combinator) run synchronously, in registration order, when the task settles; on an already settled
	task they run at once. No event loop or scheduler is needed, which is what makes `Task` work unchanged in a WoW
	addon (Lua 5.1) and in Lune.

	`Task.async(body)` runs `body` as a coroutine in which `Task.await(task)` suspends until `task` settles and
	returns its `Result`. Time-based helpers (`timer`, `timeout`, `withRetries`) take a `Schedule` so the host
	supplies the clock: `C_Timer.After` in WoW, `task.delay` in Lune.

	Functions that relate a task's payload to a callback or return value take the task's whole type as `K` and read
	its payload types with `ValueOf<K>` and `ReasonOf<K>`, for the reason given in Result.luau.

	Differences from true-myth: no Promises (Lua has none), so there is no `fromPromise`/`toPromise`; `async`/`await`
	replace `await task`; `withRetries` stops early through a typed `shouldRetry` option instead of a `StopRetrying`
	sentinel; delays are in seconds.

	Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
]]

local Delay = require("./Delay")
local Result = require("./Result")

type Result<T, E> = Result.Result<T, E>
type OkOf<R> = Result.OkOf<R>
type ErrOf<R> = Result.ErrOf<R>

export type Pending = { read kind: "Pending" }
export type Resolved<T> = { read kind: "Resolved", read value: T }
export type Rejected<E> = { read kind: "Rejected", read reason: E }
export type State<T, E> = Pending | Resolved<T> | Rejected<E>

--- The public view of a task: its current state, read-only. Settle it only through the executor or resolvers.
export type Task<T, E> = { read state: State<T, E> }

-- The type of `field` on the states of `task` whose `kind` is `tag`; never if there is none. Raises a type error
-- when `task` is not a Task. `any` passes through.
type function taskPayload(task: type, tag: type, field: type): type
	if task:is("any") then
		return types.any
	elseif task:is("never") then
		return types.never
	end
	local state = if task:is("table") then task:readproperty(types.singleton("state")) else nil
	if state == nil then
		error("expected a Task, got " .. tostring(task), 0)
	end
	local variants = if state:is("union") then state:components() else { state }
	local found = {}
	for _, variant in variants do
		local kind = if variant:is("table") then variant:readproperty(types.singleton("kind")) else nil
		local name = if kind and kind:is("singleton") then kind:value() else nil
		if name ~= "Pending" and name ~= "Resolved" and name ~= "Rejected" then
			error("expected a Task, got " .. tostring(task), 0)
		end
		if name == tag:value() then
			local payload = variant:readproperty(field)
			if payload then
				table.insert(found, payload)
			end
		end
	end
	if #found == 0 then
		return types.never
	elseif #found == 1 then
		return found[1]
	end
	return types.unionof(table.unpack(found))
end

--- The value type of a task type: `ValueOf<Task<number, string>>` is `number`.
export type ValueOf<K> = taskPayload<K, "Resolved", "value">
--- The rejection type of a task type: `ReasonOf<Task<number, string>>` is `string`.
export type ReasonOf<K> = taskPayload<K, "Rejected", "reason">

--- Handlers for `Task.match`: one per settled variant, both returning the same type.
export type Matcher<T, E, A> = { read Resolved: (value: T) -> A, read Rejected: (reason: E) -> A }

--- A pending task with the functions that settle it (`Task.withResolvers`).
export type Deferred<T, E> = {
	read task: Task<T, E>,
	read resolve: (value: T) -> (),
	read reject: (reason: E) -> (),
}

--- Runs `callback` after `seconds`. WoW: `C_Timer.After`. Lune: `function(s, f) task.delay(s, f) end`.
export type Schedule = (seconds: number, callback: () -> ()) -> ()

--- The rejection reason of `Task.timeout` when the time runs out first.
export type Timeout = { read kind: "Timeout", read seconds: number }

--- Passed to each attempt of `Task.withRetries`.
export type RetryStatus = {
	--- 0 for the first attempt, then 1, 2, ...
	read count: number,
	--- The sum of the delays waited so far, in seconds.
	read elapsed: number,
}

--- The rejection reason of `Task.withRetries` when it gives up.
export type RetryFailed<E> = {
	read kind: "RetryFailed",
	--- How many attempts ran.
	read tries: number,
	--- The sum of the delays waited, in seconds.
	read elapsed: number,
	--- Every rejection reason, in order; the last one is why it gave up.
	read rejections: { E },
}

export type RetryOptions<E> = {
	--- The delays between attempts; the default is three immediate retries. A strategy that returns nil stops.
	read strategy: Delay.Strategy?,
	--- Waits between attempts. Required unless every delay is 0.
	read schedule: Schedule?,
	--- Return false to stop retrying after this rejection. Default: always retry.
	read shouldRetry: ((reason: E, status: RetryStatus) -> boolean)?,
}

-- The private, mutable shape behind every public `Task<T, E>`. It is deliberately not generic: Luau's new solver
-- fails to instantiate generic local helpers called from closures inside generic functions (luau-lsp 1.70.1 reports
-- bogus errors or crashes when the module is checked as a dependency), so the payloads are `any` here, in this one
-- private type. Soundness holds by construction: a task's value and reason are written only by `resolveInternal`
-- and `rejectInternal`, which every public function calls with arguments typed by that task's public type.
type Internal = {
	state: State<any, any>,
	waiters: { (result: Result<any, any>) -> () },
}

local PENDING: Pending = { kind = "Pending" }

-- Threads created by `Task.async`: `Task.await` may only suspend these. Weak keys, so finished threads are freed.
-- SAFETY: setmetatable returns its first argument, the empty map this annotation describes.
local asyncThreads: { [thread]: true } = setmetatable({}, { __mode = "k" }) :: any

local Task = {}

local function newInternal(): Internal
	return { state = PENDING, waiters = {} }
end

local function internal(task: unknown): Internal
	-- SAFETY: every task is created by `newInternal`, and every generic `K` is checked by `ValueOf`/`ReasonOf` in
	-- its signature (they fail to type-check unless `K` is a Task); the public type only hides this shape.
	return task :: any
end

local function toResult(state: Resolved<any> | Rejected<any>): Result<any, any>
	if state.kind == "Resolved" then
		return Result.ok(state.value)
	end
	return Result.err(state.reason)
end

local function settle(task: Internal, state: Resolved<any> | Rejected<any>)
	if task.state.kind ~= "Pending" then
		return -- a task settles once; later calls are ignored
	end
	task.state = state
	local waiters = task.waiters
	task.waiters = {}
	local result = toResult(state)
	for _, waiter in ipairs(waiters) do
		waiter(result)
	end
end

local function resolveInternal(task: Internal, value: unknown)
	settle(task, { kind = "Resolved", value = value })
end

local function rejectInternal(task: Internal, reason: unknown)
	settle(task, { kind = "Rejected", reason = reason })
end

-- Calls `callback` with the task's result once it settles (at once if it has).
local function onSettled(task: unknown, callback: (result: Result<any, any>) -> ())
	local inner = internal(task)
	local state = inner.state
	if state.kind == "Pending" then
		table.insert(inner.waiters, callback)
	else
		callback(toResult(state))
	end
end

-- Settles `target` the way `source` settles.
local function follow(source: unknown, target: Internal)
	onSettled(source, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveInternal(target, result.value)
		else
			rejectInternal(target, result.error)
		end
	end)
end

--- Calls `callback` with the task's `Result` once it settles (at once if it already has).
function Task.whenSettled<K>(task: K, callback: (result: Result<ValueOf<K>, ReasonOf<K>>) -> ())
	onSettled(task, callback)
end

--- A task settled by `executor(resolve, reject)`. The executor runs at once; it may settle later (from a timer or
--- event callback). The first settlement wins. An error raised by the executor is a defect and propagates.
function Task.new<T, E>(executor: (resolve: (value: T) -> (), reject: (reason: E) -> ()) -> ()): Task<T, E>
	local task = newInternal()
	executor(function(value: T)
		resolveInternal(task, value)
	end, function(reason: E)
		rejectInternal(task, reason)
	end)
	return task
end

--- A pending task and the functions that settle it. Luau cannot infer types used only in a result, so name them:
--- `local d = Task.withResolvers() :: Task.Deferred<number, string>`.
function Task.withResolvers<T, E>(): Deferred<T, E>
	local task = newInternal()
	return {
		task = task,
		resolve = function(value: T)
			resolveInternal(task, value)
		end,
		reject = function(reason: E)
			rejectInternal(task, reason)
		end,
	}
end

--- A task already resolved with `value`.
function Task.resolve<T>(value: T): Task<T, never>
	local task = newInternal()
	resolveInternal(task, value)
	return task
end

--- A task already rejected with `reason`.
function Task.reject<E>(reason: E): Task<never, E>
	local task = newInternal()
	rejectInternal(task, reason)
	return task
end

--- A settled task from a `Result`: `Ok` resolves, `Err` rejects.
function Task.fromResult<R>(result: R): Task<OkOf<R>, ErrOf<R>>
	local task = newInternal()
	-- SAFETY: `R` is checked by `OkOf<R>` in this signature, so it is a Result.
	local r = (result :: any) :: Result<any, any>
	if r.kind == "Ok" then
		resolveInternal(task, r.value)
	else
		rejectInternal(task, r.error)
	end
	return task
end

--- The task's `Result` if it has settled, otherwise nil.
function Task.peek<K>(task: K): Result<ValueOf<K>, ReasonOf<K>>?
	local state = internal(task).state
	if state.kind == "Pending" then
		return nil
	end
	return toResult(state)
end

--- True while the task has not settled.
function Task.isPending<T, E>(task: Task<T, E>): boolean
	return task.state.kind == "Pending"
end

--- True once the task has resolved.
function Task.isResolved<T, E>(task: Task<T, E>): boolean
	return task.state.kind == "Resolved"
end

--- True once the task has rejected.
function Task.isRejected<T, E>(task: Task<T, E>): boolean
	return task.state.kind == "Rejected"
end

--- Resolves with `f(value)`; a rejection passes through.
function Task.map<K, U>(task: K, f: (value: ValueOf<K>) -> U): Task<U, ReasonOf<K>>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveInternal(target, f(result.value))
		else
			rejectInternal(target, result.error)
		end
	end)
	return target
end

--- Rejects with `f(reason)`; a resolution passes through.
function Task.mapRejected<K, F>(task: K, f: (reason: ReasonOf<K>) -> F): Task<ValueOf<K>, F>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveInternal(target, result.value)
		else
			rejectInternal(target, f(result.error))
		end
	end)
	return target
end

--- Chains an asynchronous step: on resolution, settles like `f(value)`; a rejection passes through. The rejection
--- types add up.
function Task.andThen<K, L>(task: K, f: (value: ValueOf<K>) -> L): Task<ValueOf<L>, ReasonOf<K> | ReasonOf<L>>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			follow(f(result.value), target)
		else
			rejectInternal(target, result.error)
		end
	end)
	return target
end

--- Recovers from a rejection: on rejection, settles like `f(reason)`; a resolution passes through.
function Task.orElse<K, L>(task: K, f: (reason: ReasonOf<K>) -> L): Task<ValueOf<K> | ValueOf<L>, ReasonOf<L>>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveInternal(target, result.value)
		else
			follow(f(result.error), target)
		end
	end)
	return target
end

--- Settles like `other` if `task` resolves, otherwise rejects with `task`'s reason. (`and` is a Lua keyword.)
function Task.and_<K, L>(task: K, other: L): Task<ValueOf<L>, ReasonOf<K> | ReasonOf<L>>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			follow(other, target)
		else
			rejectInternal(target, result.error)
		end
	end)
	return target
end

--- Resolves like `task` if it resolves, otherwise settles like `other`. (`or` is a Lua keyword.)
function Task.or_<K, L>(task: K, other: L): Task<ValueOf<K> | ValueOf<L>, ReasonOf<L>>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveInternal(target, result.value)
		else
			follow(other, target)
		end
	end)
	return target
end

--- Resolves with the matching handler's result once `task` settles; never rejects.
function Task.match<K, A>(task: K, matcher: Matcher<ValueOf<K>, ReasonOf<K>, A>): Task<A, never>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveInternal(target, matcher.Resolved(result.value))
		else
			resolveInternal(target, matcher.Rejected(result.error))
		end
	end)
	return target
end

--- Resolves with the task's `Result`; never rejects.
function Task.toResult<K>(task: K): Task<Result<ValueOf<K>, ReasonOf<K>>, never>
	local target = newInternal()
	onSettled(task, function(result: Result<any, any>)
		resolveInternal(target, result)
	end)
	return target
end

--- Calls `f` with the value for its side effect when `task` resolves; returns `task`.
function Task.inspect<K>(task: K, f: (value: ValueOf<K>) -> ()): K
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			f(result.value)
		end
	end)
	return task
end

--- Calls `f` with the reason for its side effect when `task` rejects; returns `task`.
function Task.inspectRejected<K>(task: K, f: (reason: ReasonOf<K>) -> ()): K
	onSettled(task, function(result: Result<any, any>)
		if result.kind == "Err" then
			f(result.error)
		end
	end)
	return task
end

--- Resolves with every value in order once all resolve; rejects with the first rejection. Empty: resolves `{}`.
function Task.all<K>(tasks: { K }): Task<{ ValueOf<K> }, ReasonOf<K>>
	local target = newInternal()
	local values: { any } = {}
	local remaining = #tasks
	if remaining == 0 then
		resolveInternal(target, values)
		return target
	end
	for index, task in ipairs(tasks) do
		onSettled(task, function(result: Result<any, any>)
			if result.kind == "Ok" then
				values[index] = result.value
				remaining = remaining - 1
				if remaining == 0 then
					resolveInternal(target, values)
				end
			else
				rejectInternal(target, result.error)
			end
		end)
	end
	return target
end

--- Resolves with every task's `Result` in order once all settle; never rejects.
function Task.allSettled<K>(tasks: { K }): Task<{ Result<ValueOf<K>, ReasonOf<K>> }, never>
	local target = newInternal()
	local results: { Result<any, any> } = {}
	local remaining = #tasks
	if remaining == 0 then
		resolveInternal(target, results)
		return target
	end
	for index, task in ipairs(tasks) do
		onSettled(task, function(result: Result<any, any>)
			results[index] = result
			remaining = remaining - 1
			if remaining == 0 then
				resolveInternal(target, results)
			end
		end)
	end
	return target
end

--- Resolves with the first resolution; rejects with every reason in order once all reject. Empty: rejects `{}`.
function Task.any<K>(tasks: { K }): Task<ValueOf<K>, { ReasonOf<K> }>
	local target = newInternal()
	local reasons: { any } = {}
	local remaining = #tasks
	if remaining == 0 then
		rejectInternal(target, reasons)
		return target
	end
	for index, task in ipairs(tasks) do
		onSettled(task, function(result: Result<any, any>)
			if result.kind == "Ok" then
				resolveInternal(target, result.value)
			else
				reasons[index] = result.error
				remaining = remaining - 1
				if remaining == 0 then
					rejectInternal(target, reasons)
				end
			end
		end)
	end
	return target
end

--- Settles like the first task to settle. Empty: stays pending forever.
function Task.race<K>(tasks: { K }): Task<ValueOf<K>, ReasonOf<K>>
	local target = newInternal()
	for _, task in ipairs(tasks) do
		follow(task, target)
	end
	return target
end

--- Runs `body` as a coroutine in which `Task.await` may suspend. The task settles with the `Result` that `body`
--- returns: `Ok` resolves, `Err` rejects. An error raised by `body` is a defect and propagates.
---
--- Lua 5.1 (WoW) cannot suspend a coroutine across `pcall` or a metamethod, so do not `Task.await` inside one.
function Task.async<R>(body: () -> R): Task<OkOf<R>, ErrOf<R>>
	local task = newInternal()
	local thread = coroutine.create(function()
		-- SAFETY: `R` is checked by `OkOf<R>` in this signature, so `body` returns a Result.
		local result = (body() :: any) :: Result<any, any>
		if result.kind == "Ok" then
			resolveInternal(task, result.value)
		else
			rejectInternal(task, result.error)
		end
	end)
	asyncThreads[thread] = true
	local ok, raised = coroutine.resume(thread)
	if not ok then
		error(raised, 0)
	end
	return task
end

--- Inside `Task.async`: suspends until `task` settles and returns its `Result` (at once if it has settled).
--- Calling it anywhere else is a defect and raises.
function Task.await<K>(task: K): Result<ValueOf<K>, ReasonOf<K>>
	local state = internal(task).state
	if state.kind ~= "Pending" then
		return toResult(state)
	end
	local thread = coroutine.running()
	if thread == nil or not asyncThreads[thread] then
		error("Task.await: called outside Task.async", 2)
	end
	local settled: Result<any, any>? = nil
	onSettled(task, function(result: Result<any, any>)
		settled = result
		local ok, raised = coroutine.resume(thread)
		if not ok then
			error(raised, 0)
		end
	end)
	-- Our waiter is the only code that resumes this thread while `settled` is nil.
	while true do
		local result = settled
		if result ~= nil then
			return result
		end
		coroutine.yield()
	end
end

--- Resolves with `seconds` after `seconds` have passed.
function Task.timer(seconds: number, schedule: Schedule): Task<number, never>
	local task = newInternal()
	schedule(seconds, function()
		resolveInternal(task, seconds)
	end)
	return task
end

--- Settles like `task`, unless `seconds` pass first: then it rejects with `Timeout`.
function Task.timeout<K>(task: K, seconds: number, schedule: Schedule): Task<ValueOf<K>, ReasonOf<K> | Timeout>
	local target = newInternal()
	follow(task, target)
	schedule(seconds, function()
		local timeout: Timeout = { kind = "Timeout", seconds = seconds }
		rejectInternal(target, timeout)
	end)
	return target
end

--- Runs `retryable` until its task resolves, waiting `strategy`'s delays between attempts. Rejects with
--- `RetryFailed` when the strategy runs out or `shouldRetry` returns false.
function Task.withRetries<K>(
	retryable: (status: RetryStatus) -> K,
	options: RetryOptions<ReasonOf<K>>?
): Task<ValueOf<K>, RetryFailed<ReasonOf<K>>>
	local strategy = if options and options.strategy then options.strategy else Delay.take(Delay.immediate(), 3)
	local schedule = if options then options.schedule else nil
	local shouldRetry = if options then options.shouldRetry else nil
	local target = newInternal()
	local rejections: { any } = {}
	local elapsed = 0

	local function attempt(count: number)
		local status: RetryStatus = { count = count, elapsed = elapsed }
		onSettled(retryable(status), function(result: Result<any, any>)
			if result.kind == "Ok" then
				resolveInternal(target, result.value)
				return
			end
			table.insert(rejections, result.error)
			local delay = if shouldRetry == nil or shouldRetry(result.error, status) then strategy() else nil
			if delay == nil then
				local failed: RetryFailed<any> = {
					kind = "RetryFailed",
					tries = count + 1,
					elapsed = elapsed,
					rejections = rejections,
				}
				rejectInternal(target, failed)
				return
			end
			elapsed = elapsed + delay
			if delay <= 0 then
				attempt(count + 1)
			elseif schedule then
				schedule(delay, function()
					attempt(count + 1)
				end)
			else
				error("Task.withRetries: a delay above 0 needs options.schedule", 0)
			end
		end)
	end

	attempt(0)
	return target
end

return Task
