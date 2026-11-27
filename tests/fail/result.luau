--!strict
local Exhaustive = require("../../packages/true-myth/src/Exhaustive")
local Result = require("../../packages/true-myth/src/Result")

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

local _error = found.error -- expect-error: Key 'error' is missing from 'Ok<string>'
if found.kind == "Ok" then
	local _misread = found.error -- expect-error: Key 'error' not found in table 'Ok<string>'
end

local function _badReturn(): Result<string, LookupError>
	return Result.err("bad input") -- expect-error: but got 'Err<string>'
end

local _ = Result.mapErr(found, function(e: string): string -- expect-error: Expected the 1st parameter to be a supertype
	return e
end)

local function _describe(e: LookupError): string
	if e.kind == "NotFound" then
		return "missing " .. e.id
	elseif e.kind == "Invalid" then
		return e.reason
	end
	return Exhaustive.casesHandled(e) -- expect-error: Timeout
end

local _ = function(r: Result.Ok<number>)
	r.value = 0 -- expect-error: is read-only
end
