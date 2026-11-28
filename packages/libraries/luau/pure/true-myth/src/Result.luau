--!strict
local Show = require("./Show")

export type Ok<T> = { read kind: "Ok", read value: T }
export type Err<E> = { read kind: "Err", read error: E }
export type Result<T, E> = Ok<T> | Err<E>

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

export type OkOf<R> = resultPayload<R, "Ok", "value">
export type ErrOf<R> = resultPayload<R, "Err", "error">

export type Matcher<T, E, A> = { read Ok: (value: T) -> A, read Err: (error: E) -> A }

local Result = {}

local function uncheckedView(result: unknown): Result<any, any>
	return result :: any
end

function Result.ok<T>(value: T): Ok<T>
	return { kind = "Ok", value = value }
end

function Result.err<E>(error: E): Err<E>
	return { kind = "Err", error = error }
end

function Result.isOk<T, E>(result: Result<T, E>): boolean
	return result.kind == "Ok"
end

function Result.isErr<T, E>(result: Result<T, E>): boolean
	return result.kind == "Err"
end

function Result.map<R, U>(result: R, f: (value: OkOf<R>) -> U): Result<U, ErrOf<R>>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return Result.ok(f(r.value))
	end
	return r
end

function Result.mapErr<R, F>(result: R, f: (error: ErrOf<R>) -> F): Result<OkOf<R>, F>
	local r = uncheckedView(result)
	if r.kind == "Err" then
		return Result.err(f(r.error))
	end
	return r
end

function Result.mapOr<R, U>(result: R, default: U, f: (value: OkOf<R>) -> U): U
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return f(r.value)
	end
	return default
end

function Result.mapOrElse<R, U>(result: R, orElse: (error: ErrOf<R>) -> U, f: (value: OkOf<R>) -> U): U
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return f(r.value)
	end
	return orElse(r.error)
end

function Result.match<R, A>(result: R, matcher: Matcher<OkOf<R>, ErrOf<R>, A>): A
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return matcher.Ok(r.value)
	end
	return matcher.Err(r.error)
end

function Result.andThen<R, S>(result: R, f: (value: OkOf<R>) -> S): Result<OkOf<S>, ErrOf<R> | ErrOf<S>>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return uncheckedView(f(r.value))
	end
	return r
end

function Result.and_<R, S>(result: R, other: S): Result<OkOf<S>, ErrOf<R> | ErrOf<S>>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return uncheckedView(other)
	end
	return r
end

function Result.or_<R, S>(result: R, other: S): Result<OkOf<R> | OkOf<S>, ErrOf<S>>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return r
	end
	return uncheckedView(other)
end

function Result.orElse<R, S>(result: R, f: (error: ErrOf<R>) -> S): Result<OkOf<R> | OkOf<S>, ErrOf<S>>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return r
	end
	return uncheckedView(f(r.error))
end

function Result.unwrapOr<R>(result: R, default: OkOf<R>): OkOf<R>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return r.value
	end
	return default
end

function Result.unwrapOrElse<R>(result: R, f: (error: ErrOf<R>) -> OkOf<R>): OkOf<R>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return r.value
	end
	return f(r.error)
end

function Result.flatten<R>(result: R): Result<OkOf<OkOf<R>>, ErrOf<R> | ErrOf<OkOf<R>>>
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		return uncheckedView(r.value)
	end
	return r
end

function Result.equals<T, E>(a: Result<T, E>, b: Result<T, E>): boolean
	if a.kind == "Ok" and b.kind == "Ok" then
		return a.value == b.value
	elseif a.kind == "Err" and b.kind == "Err" then
		return a.error == b.error
	end
	return false
end

function Result.toString<T, E>(result: Result<T, E>): string
	return Show.value(result)
end

function Result.inspect<R>(result: R, f: (value: OkOf<R>) -> ()): R
	local r = uncheckedView(result)
	if r.kind == "Ok" then
		f(r.value)
	end
	return result
end

function Result.inspectErr<R>(result: R, f: (error: ErrOf<R>) -> ()): R
	local r = uncheckedView(result)
	if r.kind == "Err" then
		f(r.error)
	end
	return result
end

function Result.all<R>(results: { R }): Result<{ OkOf<R> }, ErrOf<R>>
	local values: { any } = {}
	for _, result in ipairs(results) do
		local r = uncheckedView(result)
		if r.kind == "Err" then
			return r
		end
		table.insert(values, r.value)
	end
	return Result.ok(values)
end

function Result.any<R>(results: { R }): Result<OkOf<R>, { ErrOf<R> }>
	local errors: { any } = {}
	for _, result in ipairs(results) do
		local r = uncheckedView(result)
		if r.kind == "Ok" then
			return r
		end
		table.insert(errors, r.error)
	end
	return Result.err(errors)
end

function Result.partition<R>(results: { R }): ({ OkOf<R> }, { ErrOf<R> })
	local values: { any }, errors: { any } = {}, {}
	for _, result in ipairs(results) do
		local r = uncheckedView(result)
		if r.kind == "Ok" then
			table.insert(values, r.value)
		else
			table.insert(errors, r.error)
		end
	end
	return values, errors
end

function Result.tryOr<T, E>(error: E, f: () -> T): Result<T, E>
	local ok, value = pcall(f)
	if ok then
		return Result.ok(value)
	end
	return Result.err(error)
end

function Result.tryOrElse<T, E>(onError: (raised: unknown) -> E, f: () -> T): Result<T, E>
	local ok, value = pcall(f)
	if ok then
		return Result.ok(value)
	end
	return Result.err(onError(value))
end

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
