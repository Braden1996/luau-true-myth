--!strict
-- Negative fixture: every marked line must produce a type error containing its phrase (new solver).
local Exhaustive = require("../../src/Exhaustive")
local Result = require("../../src/Result")

type Result<T, E> = Result.Result<T, E>

type NotFound = { read kind: "NotFound", read id: number }
type Invalid = { read kind: "Invalid", read reason: string }
type Timeout = { read kind: "Timeout" }
type LookupError = NotFound | Invalid | Timeout

local function lookup(id: number): Result<string, LookupError>
	if id < 0 then
		return Result.err({ kind = "Invalid", reason = "negative" } :: Invalid)
	end
	return Result.ok("quest")
end

local found = lookup(1)

-- The error is only on Err, the value only on Ok: narrow first.
local _error = found.error -- expect-error: Key 'error' is missing from 'Ok<string>'
if found.kind == "Ok" then
	local _misread = found.error -- expect-error: Key 'error' not found in table 'Ok<string>'
end

-- A returned error must have the declared error type.
local function _badReturn(): Result<string, LookupError>
	return Result.err("bad input") -- expect-error: but got 'Err<string>'
end

-- Callbacks see the right side's type.
local _ = Result.mapErr(found, function(e: string): string -- expect-error: Expected the 1st parameter to be a supertype
	return e
end)

-- Exhaustiveness: forgetting a variant (Timeout) is an error at casesHandled.
local function _describe(e: LookupError): string
	if e.kind == "NotFound" then
		return "missing " .. e.id
	elseif e.kind == "Invalid" then
		return e.reason
	end
	return Exhaustive.casesHandled(e) -- expect-error: Timeout
end

-- Results are read-only.
local _ = function(r: Result.Ok<number>)
	r.value = 0 -- expect-error: is read-only
end
