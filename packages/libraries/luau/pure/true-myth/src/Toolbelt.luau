--!strict
local Maybe = require("./Maybe")
local Result = require("./Result")

type Maybe<T> = Maybe.Maybe<T>
type Result<T, E> = Result.Result<T, E>
type ValueOf<M> = Maybe.ValueOf<M>
type OkOf<R> = Result.OkOf<R>
type ErrOf<R> = Result.ErrOf<R>

local Toolbelt = {}

local function uncheckedMaybe(maybe: unknown): Maybe<any>
	return maybe :: any
end

local function uncheckedResult(result: unknown): Result<any, any>
	return result :: any
end

function Toolbelt.toMaybe<R>(result: R): Maybe<OkOf<R>>
	local r = uncheckedResult(result)
	if r.kind == "Ok" then
		return Maybe.just(r.value)
	end
	return Maybe.nothing()
end

function Toolbelt.toOkOrErr<M, E>(maybe: M, error: E): Result<ValueOf<M>, E>
	local m = uncheckedMaybe(maybe)
	if m.kind == "Just" then
		return Result.ok(m.value)
	end
	return Result.err(error)
end

function Toolbelt.toOkOrElseErr<M, E>(maybe: M, f: () -> E): Result<ValueOf<M>, E>
	local m = uncheckedMaybe(maybe)
	if m.kind == "Just" then
		return Result.ok(m.value)
	end
	return Result.err(f())
end

function Toolbelt.transposeResult<R>(result: R): Maybe<Result<ValueOf<OkOf<R>>, ErrOf<R>>>
	local r = uncheckedResult(result)
	if r.kind == "Err" then
		return Maybe.just(r)
	end
	local m = uncheckedMaybe(r.value)
	if m.kind == "Just" then
		return Maybe.just(Result.ok(m.value))
	end
	return Maybe.nothing()
end

function Toolbelt.transposeMaybe<M>(maybe: M): Result<Maybe<OkOf<ValueOf<M>>>, ErrOf<ValueOf<M>>>
	local m = uncheckedMaybe(maybe)
	if m.kind == "Nothing" then
		return Result.ok(Maybe.nothing())
	end
	local r = uncheckedResult(m.value)
	if r.kind == "Ok" then
		return Result.ok(Maybe.just(r.value))
	end
	return r
end

return Toolbelt
