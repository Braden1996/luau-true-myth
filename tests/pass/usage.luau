--!strict
-- Positive fixture: idiomatic use must type-check with zero diagnostics (new solver), with no casts in user code.
local TrueMyth = require("../../src/TrueMyth")

local Maybe, Result, Task, Toolbelt = TrueMyth.Maybe, TrueMyth.Result, TrueMyth.Task, TrueMyth.Toolbelt

type Maybe<T> = TrueMyth.Maybe<T>
type Result<T, E> = TrueMyth.Result<T, E>
type Task<T, E> = TrueMyth.Task<T, E>

-- Tagged errors with literal kinds, matched exhaustively.
type NotFound = { read kind: "NotFound", read id: number }
type Invalid = { read kind: "Invalid", read reason: string }
type LookupError = NotFound | Invalid

local quests: { [number]: string } = { [1] = "A Threat Within" }

local function findQuest(id: number): Result<string, LookupError>
	if id <= 0 then
		return Result.err({ kind = "Invalid", reason = "id must be positive" } :: Invalid)
	end
	return Toolbelt.toOkOrErr(Maybe.get(quests, id), { kind = "NotFound", id = id } :: NotFound)
end

local function describe(e: LookupError): string
	if e.kind == "NotFound" then
		return "no quest " .. e.id
	end
	return "invalid: " .. e.reason
end

local title: string = Result.mapOrElse(findQuest(1), describe, string.upper)
local length: number = Result.unwrapOr(Result.map(findQuest(2), string.len), 0)

-- Narrowing on `kind`.
local found = findQuest(1)
if found.kind == "Ok" then
	local _t: string = found.value
else
	local _e: LookupError = found.error
end

-- Maybe from nilable values; the element type has nil removed.
local maybeLevel: number? = nil
local level: Maybe<number> = Maybe.of(maybeLevel)
local next: Maybe<number> = Maybe.map(level, function(n: number): number
	return n + 1
end)
local shown: string = Maybe.match(next, {
	Just = function(n: number): string
		return tostring(n)
	end,
	Nothing = function(): string
		return "unknown"
	end,
})

-- Ok and Err need no annotations to fit any Result.
local function safeDivide(a: number, b: number): Result<number, "DivideByZero">
	if b == 0 then
		return Result.err("DivideByZero")
	end
	return Result.ok(a / b)
end
local all: Result<{ number }, "DivideByZero"> = Result.all({ safeDivide(1, 2), safeDivide(3, 4) })

-- Tasks: async/await with Results, and combinators.
local deferred = Task.withResolvers() :: TrueMyth.Deferred<number, string>
local doubled: Task<number, string> = Task.map(deferred.task, function(n: number): number
	return n * 2
end)
local summed: Task<number, string> = Task.async(function(): Result<number, string>
	local a = Task.await(doubled)
	if a.kind == "Err" then
		return a
	end
	return Result.ok(a.value + 1)
end)
local resolved: Task<number, never> = Task.resolve(1)
local widened: Task<number, string> = resolved
local both: Task<{ number }, string> = Task.all({ summed, widened })
local limited: Task<{ number }, string | TrueMyth.Timeout> = Task.timeout(both, 5, function(_: number, _: () -> ()) end)

print(title, length, shown, all, limited)
