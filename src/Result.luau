--!strict
--[[
	Result: the outcome of an operation that can fail, as a value.

	A `Result<T, E>` is either `Ok<T>` (`{ kind = "Ok", value = T }`) or `Err<E>` (`{ kind = "Err", error = E }`).
	Both are plain, read-only tables: no metatables, so they survive serialisation (WoW SavedVariables, JSON) and
	compare structurally with `Result.equals`. Narrow with `if r.kind == "Ok" then ... r.value ... end`.

	`Ok<T>` carries no error type and `Err<E>` no value type, so `Result.ok(1)` is assignable to any
	`Result<number, E>` without annotations.

	Functions that relate a result's payload to a callback, default or return value take the result's whole type
	as `R` and read its payload types with `OkOf<R>` and `ErrOf<R>` (type functions). Luau's new solver, given
	`Result<T, E>` as a parameter, infers `T` from the `Err` variant too (as nil) and then rejects annotated
	callbacks such as `function(n: number)`; inferring the whole type avoids that. See docs/design.md.

	Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
]]

local Show = require("./Show")

export type Ok<T> = { read kind: "Ok", read value: T }
export type Err<E> = { read kind: "Err", read error: E }
export type Result<T, E> = Ok<T> | Err<E>

-- The type of `field` on the variants of `result` whose `kind` is `tag`; never if there is none. Raises a type
-- error when `result` is not a Result. `any` passes through.
type function resultPayload(result: type, tag: type, field: type): type
	if result:is("any") then
		return types.any
	elseif result:is("never") then
		return types.never
	end
	local variants = if result:is("union") then result:components() else { result }
	local found = {}
	for _, variant in variants do
		local kind = if variant:is("table") then variant:readproperty(types.singleton("kind")) else nil
		local name = if kind and kind:is("singleton") then kind:value() else nil
		if name ~= "Ok" and name ~= "Err" then
			error("expected a Result, got " .. tostring(result), 0)
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

--- The value type of a result type: `OkOf<Result<number, string>>` is `number`.
export type OkOf<R> = resultPayload<R, "Ok", "value">
--- The error type of a result type: `ErrOf<Result<number, string>>` is `string`.
export type ErrOf<R> = resultPayload<R, "Err", "error">

--- Handlers for `Result.match`: one per variant, both returning the same type.
export type Matcher<T, E, A> = { read Ok: (value: T) -> A, read Err: (error: E) -> A }

local Result = {}

-- The runtime view of a result whose static type is a generic `R`.
local function view(result: unknown): Result<any, any>
	-- SAFETY: every `R` parameter is checked by `OkOf<R>`/`ErrOf<R>` in the same signature, which fail to type-check
	-- unless `R` is a Result; this only forgets the payload types, which the signature restores.
	return result :: any
end

--- `Ok(value)`. `value` may be nil: `Result<nil, E>` is a success with no payload.
function Result.ok<T>(value: T): Ok<T>
	return { kind = "Ok", value = value }
end

--- `Err(error)`.
function Result.err<E>(error: E): Err<E>
	return { kind = "Err", error = error }
end

--- True for `Ok`. To narrow the type, compare `r.kind == "Ok"` instead: Luau has no user-defined type guards.
function Result.isOk<T, E>(result: Result<T, E>): boolean
	return result.kind == "Ok"
end

--- True for `Err`. To narrow the type, compare `r.kind == "Err"` instead.
function Result.isErr<T, E>(result: Result<T, E>): boolean
	return result.kind == "Err"
end

--- Applies `f` to an `Ok` value; passes an `Err` through.
function Result.map<R, U>(result: R, f: (value: OkOf<R>) -> U): Result<U, ErrOf<R>>
	local r = view(result)
	if r.kind == "Ok" then
		return Result.ok(f(r.value))
	end
	return r
end

--- Applies `f` to an `Err` error; passes an `Ok` through.
function Result.mapErr<R, F>(result: R, f: (error: ErrOf<R>) -> F): Result<OkOf<R>, F>
	local r = view(result)
	if r.kind == "Err" then
		return Result.err(f(r.error))
	end
	return r
end

--- `f(value)` for `Ok`, otherwise `default`.
function Result.mapOr<R, U>(result: R, default: U, f: (value: OkOf<R>) -> U): U
	local r = view(result)
	if r.kind == "Ok" then
		return f(r.value)
	end
	return default
end

--- `f(value)` for `Ok`, otherwise `orElse(error)`.
function Result.mapOrElse<R, U>(result: R, orElse: (error: ErrOf<R>) -> U, f: (value: OkOf<R>) -> U): U
	local r = view(result)
	if r.kind == "Ok" then
		return f(r.value)
	end
	return orElse(r.error)
end

--- Calls the handler for the variant and returns its result. Exhaustive: both handlers are required.
function Result.match<R, A>(result: R, matcher: Matcher<OkOf<R>, ErrOf<R>, A>): A
	local r = view(result)
	if r.kind == "Ok" then
		return matcher.Ok(r.value)
	end
	return matcher.Err(r.error)
end

--- Chains a fallible step: `f(value)` for `Ok`, the `Err` unchanged otherwise. The error types add up.
--- (Also known as `flatMap`/`bind`.)
function Result.andThen<R, S>(result: R, f: (value: OkOf<R>) -> S): Result<OkOf<S>, ErrOf<R> | ErrOf<S>>
	local r = view(result)
	if r.kind == "Ok" then
		return view(f(r.value))
	end
	return r
end

--- `other` if `result` is `Ok`, otherwise `result`'s `Err`. (`and` is a Lua keyword, hence `and_`.)
function Result.and_<R, S>(result: R, other: S): Result<OkOf<S>, ErrOf<R> | ErrOf<S>>
	local r = view(result)
	if r.kind == "Ok" then
		return view(other)
	end
	return r
end

--- `result` if it is `Ok`, otherwise `other`. (`or` is a Lua keyword, hence `or_`.)
function Result.or_<R, S>(result: R, other: S): Result<OkOf<R> | OkOf<S>, ErrOf<S>>
	local r = view(result)
	if r.kind == "Ok" then
		return r
	end
	return view(other)
end

--- Recovers from an error: `result` if it is `Ok`, otherwise `f(error)`.
function Result.orElse<R, S>(result: R, f: (error: ErrOf<R>) -> S): Result<OkOf<R> | OkOf<S>, ErrOf<S>>
	local r = view(result)
	if r.kind == "Ok" then
		return r
	end
	return view(f(r.error))
end

--- The `Ok` value, or `default` (of the same type).
function Result.unwrapOr<R>(result: R, default: OkOf<R>): OkOf<R>
	local r = view(result)
	if r.kind == "Ok" then
		return r.value
	end
	return default
end

--- The `Ok` value, or `f(error)`.
function Result.unwrapOrElse<R>(result: R, f: (error: ErrOf<R>) -> OkOf<R>): OkOf<R>
	local r = view(result)
	if r.kind == "Ok" then
		return r.value
	end
	return f(r.error)
end

--- Removes one level of nesting: `Ok(Ok(x))` is `Ok(x)`; an inner or outer `Err` is that `Err`.
function Result.flatten<R>(result: R): Result<OkOf<OkOf<R>>, ErrOf<R> | ErrOf<OkOf<R>>>
	local r = view(result)
	if r.kind == "Ok" then
		return view(r.value)
	end
	return r
end

--- Structural equality: same variant and `==` payloads.
function Result.equals<T, E>(a: Result<T, E>, b: Result<T, E>): boolean
	if a.kind == "Ok" and b.kind == "Ok" then
		return a.value == b.value
	elseif a.kind == "Err" and b.kind == "Err" then
		return a.error == b.error
	end
	return false
end

--- `Ok(<value>)` or `Err(<error>)`; nested `Maybe`/`Result` values render recursively.
function Result.toString<T, E>(result: Result<T, E>): string
	return Show.value(result)
end

--- Calls `f` with an `Ok` value for its side effect and returns `result` unchanged.
function Result.inspect<R>(result: R, f: (value: OkOf<R>) -> ()): R
	local r = view(result)
	if r.kind == "Ok" then
		f(r.value)
	end
	return result
end

--- Calls `f` with an `Err` error for its side effect and returns `result` unchanged.
function Result.inspectErr<R>(result: R, f: (error: ErrOf<R>) -> ()): R
	local r = view(result)
	if r.kind == "Err" then
		f(r.error)
	end
	return result
end

--- `Ok` of every value in order if all are `Ok`; otherwise the first `Err`.
function Result.all<R>(results: { R }): Result<{ OkOf<R> }, ErrOf<R>>
	local values: { any } = {}
	for _, result in ipairs(results) do
		local r = view(result)
		if r.kind == "Err" then
			return r
		end
		table.insert(values, r.value)
	end
	return Result.ok(values)
end

--- The first `Ok`; otherwise `Err` of every error in order. An empty list is `Err({})`.
function Result.any<R>(results: { R }): Result<OkOf<R>, { ErrOf<R> }>
	local errors: { any } = {}
	for _, result in ipairs(results) do
		local r = view(result)
		if r.kind == "Ok" then
			return r
		end
		table.insert(errors, r.error)
	end
	return Result.err(errors)
end

--- Splits results into their `Ok` values and their `Err` errors, each in order.
function Result.partition<R>(results: { R }): ({ OkOf<R> }, { ErrOf<R> })
	local values: { any }, errors: { any } = {}, {}
	for _, result in ipairs(results) do
		local r = view(result)
		if r.kind == "Ok" then
			table.insert(values, r.value)
		else
			table.insert(errors, r.error)
		end
	end
	return values, errors
end

--- Runs `f` in protected mode: `Ok(f())`, or `Err(error)` if `f` raised. Use it at the boundary with code that
--- raises; the raised value is discarded.
function Result.tryOr<T, E>(error: E, f: () -> T): Result<T, E>
	local ok, value = pcall(f)
	if ok then
		return Result.ok(value)
	end
	return Result.err(error)
end

--- Runs `f` in protected mode: `Ok(f())`, or `Err(onError(raised))` if `f` raised. `onError` parses the raised
--- value (often a string) into a typed error.
function Result.tryOrElse<T, E>(onError: (raised: unknown) -> E, f: () -> T): Result<T, E>
	local ok, value = pcall(f)
	if ok then
		return Result.ok(value)
	end
	return Result.err(onError(value))
end

--- Wraps a function that may raise into one that returns a `Result`: `Ok` of its first return value, or
--- `Err(onError(raised))`.
function Result.safe<T, E, A...>(f: (A...) -> T, onError: (raised: unknown) -> E): (A...) -> Result<T, E>
	return function(...: A...): Result<T, E>
		local ok, value = pcall(f, ...)
		if ok then
			return Result.ok(value)
		end
		return Result.err(onError(value))
	end
end

return Result
