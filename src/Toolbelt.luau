--!strict
--[[
	Toolbelt: conversions between `Maybe` and `Result`. Kept in its own module so `Maybe` and `Result` do not
	depend on each other.

	Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
]]

local Maybe = require("./Maybe")
local Result = require("./Result")

type Maybe<T> = Maybe.Maybe<T>
type Result<T, E> = Result.Result<T, E>
type ValueOf<M> = Maybe.ValueOf<M>
type OkOf<R> = Result.OkOf<R>
type ErrOf<R> = Result.ErrOf<R>

local Toolbelt = {}

local function viewMaybe(maybe: unknown): Maybe<any>
	-- SAFETY: every generic `M` is checked by `ValueOf<M>` in its signature, which fails unless `M` is a Maybe; this
	-- only forgets the value type, which the signature restores.
	return maybe :: any
end

local function viewResult(result: unknown): Result<any, any>
	-- SAFETY: every generic `R` is checked by `OkOf<R>`/`ErrOf<R>` in its signature, which fail unless `R` is a
	-- Result; this only forgets the payload types, which the signature restores.
	return result :: any
end

--- `Just` the `Ok` value, or `Nothing` for an `Err` (the error is discarded).
function Toolbelt.toMaybe<R>(result: R): Maybe<OkOf<R>>
	local r = viewResult(result)
	if r.kind == "Ok" then
		return Maybe.just(r.value)
	end
	return Maybe.nothing()
end

--- `Ok` the `Just` value, or `Err(error)` for `Nothing`.
function Toolbelt.toOkOrErr<M, E>(maybe: M, error: E): Result<ValueOf<M>, E>
	local m = viewMaybe(maybe)
	if m.kind == "Just" then
		return Result.ok(m.value)
	end
	return Result.err(error)
end

--- `Ok` the `Just` value, or `Err(f())` for `Nothing`; `f` runs only when needed.
function Toolbelt.toOkOrElseErr<M, E>(maybe: M, f: () -> E): Result<ValueOf<M>, E>
	local m = viewMaybe(maybe)
	if m.kind == "Just" then
		return Result.ok(m.value)
	end
	return Result.err(f())
end

--- `Result<Maybe<T>, E>` to `Maybe<Result<T, E>>`: `Ok(Just(x))` is `Just(Ok(x))`, `Ok(Nothing)` is `Nothing`,
--- `Err(e)` is `Just(Err(e))`.
function Toolbelt.transposeResult<R>(result: R): Maybe<Result<ValueOf<OkOf<R>>, ErrOf<R>>>
	local r = viewResult(result)
	if r.kind == "Err" then
		return Maybe.just(r)
	end
	local m = viewMaybe(r.value)
	if m.kind == "Just" then
		return Maybe.just(Result.ok(m.value))
	end
	return Maybe.nothing()
end

--- `Maybe<Result<T, E>>` to `Result<Maybe<T>, E>`: `Just(Ok(x))` is `Ok(Just(x))`, `Just(Err(e))` is `Err(e)`,
--- `Nothing` is `Ok(Nothing)`.
function Toolbelt.transposeMaybe<M>(maybe: M): Result<Maybe<OkOf<ValueOf<M>>>, ErrOf<ValueOf<M>>>
	local m = viewMaybe(maybe)
	if m.kind == "Nothing" then
		return Result.ok(Maybe.nothing())
	end
	local r = viewResult(m.value)
	if r.kind == "Ok" then
		return Result.ok(Maybe.just(r.value))
	end
	return r
end

return Toolbelt
