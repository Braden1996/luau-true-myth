--!strict
local Delay = require("./Delay")
local Result = require("./Result")

type Result<T, E> = Result.Result<T, E>
type OkOf<R> = Result.OkOf<R>
type ErrOf<R> = Result.ErrOf<R>

export type Pending = { read kind: "Pending" }
export type Resolved<T> = { read kind: "Resolved", read value: T }
export type Rejected<E> = { read kind: "Rejected", read reason: E }
export type State<T, E> = Pending | Resolved<T> | Rejected<E>

export type Task<T, E> = { read state: State<T, E> }

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

export type ValueOf<K> = taskPayload<K, "Resolved", "value">
export type ReasonOf<K> = taskPayload<K, "Rejected", "reason">

export type Matcher<T, E, A> = { read Resolved: (value: T) -> A, read Rejected: (reason: E) -> A }

export type Deferred<T, E> = {
	read task: Task<T, E>,
	read resolve: (value: T) -> (),
	read reject: (reason: E) -> (),
}

export type Schedule = (seconds: number, callback: () -> ()) -> ()

export type Timeout = { read kind: "Timeout", read seconds: number }

export type RetryStatus = {
	read count: number,
	read elapsed: number,
}

export type RetryFailed<E> = {
	read kind: "RetryFailed",
	read tries: number,
	read elapsed: number,
	read rejections: { E },
}

export type RetryOptions<E> = {
	read strategy: Delay.Strategy?,
	read schedule: Schedule?,
	read shouldRetry: ((reason: E, status: RetryStatus) -> boolean)?,
}

type UntypedTaskRecord = {
	state: State<any, any>,
	waiters: { (result: Result<any, any>) -> () },
}

local PENDING_STATE: Pending = { kind = "Pending" }

local function uncheckedWeakKeyedThreads(): { [thread]: true }
	return setmetatable({}, { __mode = "k" }) :: any
end

local asyncThreads = uncheckedWeakKeyedThreads()

local Task = {}

local function uncheckedResult(value: unknown): Result<any, any>
	return value :: any
end

local function newPendingRecord(): UntypedTaskRecord
	return { state = PENDING_STATE, waiters = {} }
end

local function uncheckedRecordOf(task: unknown): UntypedTaskRecord
	return task :: any
end

local function toResult(state: Resolved<any> | Rejected<any>): Result<any, any>
	if state.kind == "Resolved" then
		return Result.ok(state.value)
	end
	return Result.err(state.reason)
end

local function settle(task: UntypedTaskRecord, state: Resolved<any> | Rejected<any>)
	if task.state.kind ~= "Pending" then
		return
	end
	task.state = state
	local waiters = task.waiters
	task.waiters = {}
	local result = toResult(state)
	for _, waiter in ipairs(waiters) do
		waiter(result)
	end
end

local function resolveRecord(task: UntypedTaskRecord, value: unknown)
	settle(task, { kind = "Resolved", value = value })
end

local function rejectRecord(task: UntypedTaskRecord, reason: unknown)
	settle(task, { kind = "Rejected", reason = reason })
end

local function whenRecordSettles(task: unknown, callback: (result: Result<any, any>) -> ())
	local inner = uncheckedRecordOf(task)
	local state = inner.state
	if state.kind == "Pending" then
		table.insert(inner.waiters, callback)
	else
		callback(toResult(state))
	end
end

local function settleLike(source: unknown, target: UntypedTaskRecord)
	whenRecordSettles(source, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveRecord(target, result.value)
		else
			rejectRecord(target, result.error)
		end
	end)
end

function Task.whenSettled<K>(task: K, callback: (result: Result<ValueOf<K>, ReasonOf<K>>) -> ())
	whenRecordSettles(task, callback)
end

function Task.new<T, E>(executor: (resolve: (value: T) -> (), reject: (reason: E) -> ()) -> ()): Task<T, E>
	local task = newPendingRecord()
	executor(function(value: T)
		resolveRecord(task, value)
	end, function(reason: E)
		rejectRecord(task, reason)
	end)
	return task
end

function Task.withResolvers<T, E>(): Deferred<T, E>
	local task = newPendingRecord()
	return {
		task = task,
		resolve = function(value: T)
			resolveRecord(task, value)
		end,
		reject = function(reason: E)
			rejectRecord(task, reason)
		end,
	}
end

function Task.resolve<T>(value: T): Task<T, never>
	local task = newPendingRecord()
	resolveRecord(task, value)
	return task
end

function Task.reject<E>(reason: E): Task<never, E>
	local task = newPendingRecord()
	rejectRecord(task, reason)
	return task
end

function Task.fromResult<R>(result: R): Task<OkOf<R>, ErrOf<R>>
	local task = newPendingRecord()
	local r = uncheckedResult(result)
	if r.kind == "Ok" then
		resolveRecord(task, r.value)
	else
		rejectRecord(task, r.error)
	end
	return task
end

function Task.peek<K>(task: K): Result<ValueOf<K>, ReasonOf<K>>?
	local state = uncheckedRecordOf(task).state
	if state.kind == "Pending" then
		return nil
	end
	return toResult(state)
end

function Task.isPending<T, E>(task: Task<T, E>): boolean
	return task.state.kind == "Pending"
end

function Task.isResolved<T, E>(task: Task<T, E>): boolean
	return task.state.kind == "Resolved"
end

function Task.isRejected<T, E>(task: Task<T, E>): boolean
	return task.state.kind == "Rejected"
end

function Task.map<K, U>(task: K, f: (value: ValueOf<K>) -> U): Task<U, ReasonOf<K>>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveRecord(target, f(result.value))
		else
			rejectRecord(target, result.error)
		end
	end)
	return target
end

function Task.mapRejected<K, F>(task: K, f: (reason: ReasonOf<K>) -> F): Task<ValueOf<K>, F>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveRecord(target, result.value)
		else
			rejectRecord(target, f(result.error))
		end
	end)
	return target
end

function Task.andThen<K, L>(task: K, f: (value: ValueOf<K>) -> L): Task<ValueOf<L>, ReasonOf<K> | ReasonOf<L>>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			settleLike(f(result.value), target)
		else
			rejectRecord(target, result.error)
		end
	end)
	return target
end

function Task.orElse<K, L>(task: K, f: (reason: ReasonOf<K>) -> L): Task<ValueOf<K> | ValueOf<L>, ReasonOf<L>>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveRecord(target, result.value)
		else
			settleLike(f(result.error), target)
		end
	end)
	return target
end

function Task.and_<K, L>(task: K, other: L): Task<ValueOf<L>, ReasonOf<K> | ReasonOf<L>>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			settleLike(other, target)
		else
			rejectRecord(target, result.error)
		end
	end)
	return target
end

function Task.or_<K, L>(task: K, other: L): Task<ValueOf<K> | ValueOf<L>, ReasonOf<L>>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveRecord(target, result.value)
		else
			settleLike(other, target)
		end
	end)
	return target
end

function Task.match<K, A>(task: K, matcher: Matcher<ValueOf<K>, ReasonOf<K>, A>): Task<A, never>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			resolveRecord(target, matcher.Resolved(result.value))
		else
			resolveRecord(target, matcher.Rejected(result.error))
		end
	end)
	return target
end

function Task.toResult<K>(task: K): Task<Result<ValueOf<K>, ReasonOf<K>>, never>
	local target = newPendingRecord()
	whenRecordSettles(task, function(result: Result<any, any>)
		resolveRecord(target, result)
	end)
	return target
end

function Task.inspect<K>(task: K, f: (value: ValueOf<K>) -> ()): K
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Ok" then
			f(result.value)
		end
	end)
	return task
end

function Task.inspectRejected<K>(task: K, f: (reason: ReasonOf<K>) -> ()): K
	whenRecordSettles(task, function(result: Result<any, any>)
		if result.kind == "Err" then
			f(result.error)
		end
	end)
	return task
end

function Task.all<K>(tasks: { K }): Task<{ ValueOf<K> }, ReasonOf<K>>
	local target = newPendingRecord()
	local values: { any } = {}
	local remaining = #tasks
	if remaining == 0 then
		resolveRecord(target, values)
		return target
	end
	for index, task in ipairs(tasks) do
		whenRecordSettles(task, function(result: Result<any, any>)
			if result.kind == "Ok" then
				values[index] = result.value
				remaining = remaining - 1
				if remaining == 0 then
					resolveRecord(target, values)
				end
			else
				rejectRecord(target, result.error)
			end
		end)
	end
	return target
end

function Task.allSettled<K>(tasks: { K }): Task<{ Result<ValueOf<K>, ReasonOf<K>> }, never>
	local target = newPendingRecord()
	local results: { Result<any, any> } = {}
	local remaining = #tasks
	if remaining == 0 then
		resolveRecord(target, results)
		return target
	end
	for index, task in ipairs(tasks) do
		whenRecordSettles(task, function(result: Result<any, any>)
			results[index] = result
			remaining = remaining - 1
			if remaining == 0 then
				resolveRecord(target, results)
			end
		end)
	end
	return target
end

function Task.any<K>(tasks: { K }): Task<ValueOf<K>, { ReasonOf<K> }>
	local target = newPendingRecord()
	local reasons: { any } = {}
	local remaining = #tasks
	if remaining == 0 then
		rejectRecord(target, reasons)
		return target
	end
	for index, task in ipairs(tasks) do
		whenRecordSettles(task, function(result: Result<any, any>)
			if result.kind == "Ok" then
				resolveRecord(target, result.value)
			else
				reasons[index] = result.error
				remaining = remaining - 1
				if remaining == 0 then
					rejectRecord(target, reasons)
				end
			end
		end)
	end
	return target
end

function Task.race<K>(tasks: { K }): Task<ValueOf<K>, ReasonOf<K>>
	local target = newPendingRecord()
	for _, task in ipairs(tasks) do
		settleLike(task, target)
	end
	return target
end

function Task.async<R>(body: () -> R): Task<OkOf<R>, ErrOf<R>>
	local task = newPendingRecord()
	local thread = coroutine.create(function()
		local result = uncheckedResult(body())
		if result.kind == "Ok" then
			resolveRecord(task, result.value)
		else
			rejectRecord(task, result.error)
		end
	end)
	asyncThreads[thread] = true
	local ok, raised = coroutine.resume(thread)
	if not ok then
		error(raised, 0)
	end
	return task
end

function Task.await<K>(task: K): Result<ValueOf<K>, ReasonOf<K>>
	local state = uncheckedRecordOf(task).state
	if state.kind ~= "Pending" then
		return toResult(state)
	end
	local thread = coroutine.running()
	if thread == nil or not asyncThreads[thread] then
		error("Task.await: called outside Task.async", 2)
	end
	local settled: Result<any, any>? = nil
	whenRecordSettles(task, function(result: Result<any, any>)
		settled = result
		local ok, raised = coroutine.resume(thread)
		if not ok then
			error(raised, 0)
		end
	end)
	while true do
		local result = settled
		if result ~= nil then
			return result
		end
		coroutine.yield()
	end
end

function Task.timer(seconds: number, schedule: Schedule): Task<number, never>
	local task = newPendingRecord()
	schedule(seconds, function()
		resolveRecord(task, seconds)
	end)
	return task
end

function Task.timeout<K>(task: K, seconds: number, schedule: Schedule): Task<ValueOf<K>, ReasonOf<K> | Timeout>
	local target = newPendingRecord()
	settleLike(task, target)
	schedule(seconds, function()
		local timeout: Timeout = { kind = "Timeout", seconds = seconds }
		rejectRecord(target, timeout)
	end)
	return target
end

local function delayBeforeNextAttempt(
	reason: unknown,
	status: RetryStatus,
	strategy: Delay.Strategy,
	shouldRetry: ((reason: any, status: RetryStatus) -> boolean)?
): number?
	if shouldRetry ~= nil and not shouldRetry(reason, status) then
		return nil
	end
	return strategy()
end

local function waitThen(seconds: number, schedule: Schedule?, continue: () -> ())
	if seconds <= 0 then
		continue()
	elseif schedule then
		schedule(seconds, continue)
	else
		error("Task.withRetries: a delay above 0 needs options.schedule", 0)
	end
end

function Task.withRetries<K>(
	retryable: (status: RetryStatus) -> K,
	options: RetryOptions<ReasonOf<K>>?
): Task<ValueOf<K>, RetryFailed<ReasonOf<K>>>
	local strategy = if options and options.strategy then options.strategy else Delay.take(Delay.immediate(), 3)
	local schedule = if options then options.schedule else nil
	local shouldRetry = if options then options.shouldRetry else nil
	local target = newPendingRecord()
	local rejections: { any } = {}
	local elapsed = 0

	local function giveUp(attempts: number)
		local failed: RetryFailed<any> = {
			kind = "RetryFailed",
			tries = attempts,
			elapsed = elapsed,
			rejections = rejections,
		}
		rejectRecord(target, failed)
	end

	local function attempt(count: number)
		local status: RetryStatus = { count = count, elapsed = elapsed }
		whenRecordSettles(retryable(status), function(result: Result<any, any>)
			if result.kind == "Ok" then
				resolveRecord(target, result.value)
				return
			end
			table.insert(rejections, result.error)
			local delay = delayBeforeNextAttempt(result.error, status, strategy, shouldRetry)
			if delay == nil then
				giveUp(count + 1)
				return
			end
			elapsed = elapsed + delay
			waitThen(delay, schedule, function()
				attempt(count + 1)
			end)
		end)
	end

	attempt(0)
	return target
end

return Task
