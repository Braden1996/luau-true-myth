--!strict
--[[
	Maybe: a value that may be absent, made explicit.

	A `Maybe<T>` is either `Just<T>` (`{ kind = "Just", value = T }`) or `Nothing` (`{ kind = "Nothing" }`).
	Both are plain, read-only tables: no metatables, so they survive serialisation and compare structurally with
	`Maybe.equals`. Narrow with `if m.kind == "Just" then ... m.value ... end`.

	`Nothing` carries no type parameter, so `Maybe.nothing()` is assignable to every `Maybe<T>`. A `Just` never
	holds nil: `Maybe.of(value)` turns nil into `Nothing`, and `Maybe.just(nil)` is a defect (it raises).

	Functions that relate a maybe's value to a callback, default or return value take the maybe's whole type as `M`
	and read its value type with `ValueOf<M>`, for the reason given in Result.luau.

	Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
]]

local Show = require("./Show")

export type Just<T> = { read kind: "Just", read value: T }
export type Nothing = { read kind: "Nothing" }
export type Maybe<T> = Just<T> | Nothing

--- Removes `nil` from a type: `NonNil<string?>` is `string`. The value type of `Maybe.of`.
export type function NonNil(t: type): type
	if t:is("nil") then
		return types.never
	elseif not t:is("union") then
		return t
	end
	local kept = {}
	for _, component in t:components() do
		if not component:is("nil") then
			table.insert(kept, component)
		end
	end
	if #kept == 0 then
		return types.never
	elseif #kept == 1 then
		return kept[1]
	end
	return types.unionof(table.unpack(kept))
end

--- The value type of a maybe type: `ValueOf<Maybe<number>>` is `number`; `ValueOf<Nothing>` is never. Raises a type
--- error when `M` is not a Maybe. `any` passes through.
export type function ValueOf(maybe: type): type
	if maybe:is("any") then
		return types.any
	elseif maybe:is("never") then
		return types.never
	end
	local variants = if maybe:is("union") then maybe:components() else { maybe }
	local found = {}
	for _, variant in variants do
		local kind = if variant:is("table") then variant:readproperty(types.singleton("kind")) else nil
		local name = if kind and kind:is("singleton") then kind:value() else nil
		if name ~= "Just" and name ~= "Nothing" then
			error("expected a Maybe, got " .. tostring(maybe), 0)
		end
		if name == "Just" then
			local value = variant:readproperty(types.singleton("value"))
			if value then
				table.insert(found, value)
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

--- Handlers for `Maybe.match`: one per variant, both returning the same type.
export type Matcher<T, A> = { read Just: (value: T) -> A, read Nothing: () -> A }

local NOTHING: Nothing = { kind = "Nothing" }

local Maybe = {}

-- The runtime view of a maybe whose static type is a generic `M`.
local function view(maybe: unknown): Maybe<any>
	-- SAFETY: every `M` parameter is checked by `ValueOf<M>` in the same signature, which fails to type-check unless
	-- `M` is a Maybe; this only forgets the value type, which the signature restores.
	return maybe :: any
end

--- `Just(value)`. `value` must not be nil (that is a defect and raises); use `Maybe.of` for nilable values.
function Maybe.just<T>(value: T): Just<T>
	if value == nil then
		error("Maybe.just: value is nil; use Maybe.of for a value that may be nil", 2)
	end
	return { kind = "Just", value = value }
end

--- `Nothing`. Every `Nothing` is the same shared table.
function Maybe.nothing(): Nothing
	return NOTHING
end

--- `Nothing` for nil, otherwise `Just(value)`.
function Maybe.of<T>(value: T): Maybe<NonNil<T>>
	if value == nil then
		return NOTHING
	end
	-- SAFETY: `value` is not nil here, so it is a `NonNil<T>`; Luau cannot narrow a generic by a nil check.
	return { kind = "Just", value = value :: any }
end

--- True for `Just`. To narrow the type, compare `m.kind == "Just"` instead: Luau has no user-defined type guards.
function Maybe.isJust<T>(maybe: Maybe<T>): boolean
	return maybe.kind == "Just"
end

--- True for `Nothing`.
function Maybe.isNothing<T>(maybe: Maybe<T>): boolean
	return maybe.kind == "Nothing"
end

--- `Just(f(value))` for `Just` (or `Nothing` if `f` returns nil); `Nothing` stays `Nothing`.
function Maybe.map<M, U>(maybe: M, f: (value: ValueOf<M>) -> U): Maybe<NonNil<U>>
	local m = view(maybe)
	if m.kind == "Just" then
		return Maybe.of(f(m.value))
	end
	return NOTHING
end

--- `f(value)` for `Just`, otherwise `default`.
function Maybe.mapOr<M, U>(maybe: M, default: U, f: (value: ValueOf<M>) -> U): U
	local m = view(maybe)
	if m.kind == "Just" then
		return f(m.value)
	end
	return default
end

--- `f(value)` for `Just`, otherwise `orElse()`.
function Maybe.mapOrElse<M, U>(maybe: M, orElse: () -> U, f: (value: ValueOf<M>) -> U): U
	local m = view(maybe)
	if m.kind == "Just" then
		return f(m.value)
	end
	return orElse()
end

--- Calls the handler for the variant and returns its result. Exhaustive: both handlers are required.
function Maybe.match<M, A>(maybe: M, matcher: Matcher<ValueOf<M>, A>): A
	local m = view(maybe)
	if m.kind == "Just" then
		return matcher.Just(m.value)
	end
	return matcher.Nothing()
end

--- Chains an optional step: `f(value)` for `Just`, `Nothing` otherwise. (Also known as `flatMap`/`bind`.)
function Maybe.andThen<M, N>(maybe: M, f: (value: ValueOf<M>) -> N): Maybe<ValueOf<N>>
	local m = view(maybe)
	if m.kind == "Just" then
		return view(f(m.value))
	end
	return NOTHING
end

--- `other` if `maybe` is `Just`, otherwise `Nothing`. (`and` is a Lua keyword, hence `and_`.)
function Maybe.and_<M, N>(maybe: M, other: N): Maybe<ValueOf<N>>
	if view(maybe).kind == "Just" then
		return view(other)
	end
	return NOTHING
end

--- `maybe` if it is `Just`, otherwise `other`. (`or` is a Lua keyword, hence `or_`.)
function Maybe.or_<M, N>(maybe: M, other: N): Maybe<ValueOf<M> | ValueOf<N>>
	local m = view(maybe)
	if m.kind == "Just" then
		return m
	end
	return view(other)
end

--- `maybe` if it is `Just`, otherwise `f()`.
function Maybe.orElse<M, N>(maybe: M, f: () -> N): Maybe<ValueOf<M> | ValueOf<N>>
	local m = view(maybe)
	if m.kind == "Just" then
		return m
	end
	return view(f())
end

--- The `Just` value, or `default` (of the same type).
function Maybe.unwrapOr<M>(maybe: M, default: ValueOf<M>): ValueOf<M>
	local m = view(maybe)
	if m.kind == "Just" then
		return m.value
	end
	return default
end

--- The `Just` value, or `f()`.
function Maybe.unwrapOrElse<M>(maybe: M, f: () -> ValueOf<M>): ValueOf<M>
	local m = view(maybe)
	if m.kind == "Just" then
		return m.value
	end
	return f()
end

--- Removes one level of nesting: `Just(Just(x))` is `Just(x)`; any `Nothing` is `Nothing`.
function Maybe.flatten<M>(maybe: M): Maybe<ValueOf<ValueOf<M>>>
	local m = view(maybe)
	if m.kind == "Just" then
		return view(m.value)
	end
	return NOTHING
end

--- Keeps a `Just` whose value satisfies `predicate`; anything else is `Nothing`.
function Maybe.filter<M>(maybe: M, predicate: (value: ValueOf<M>) -> boolean): Maybe<ValueOf<M>>
	local m = view(maybe)
	if m.kind == "Just" and predicate(m.value) then
		return m
	end
	return NOTHING
end

--- Structural equality: both `Nothing`, or both `Just` with `==` values.
function Maybe.equals<T>(a: Maybe<T>, b: Maybe<T>): boolean
	if a.kind == "Just" and b.kind == "Just" then
		return a.value == b.value
	end
	return a.kind == b.kind
end

--- `Just(<value>)` or `Nothing`; nested `Maybe`/`Result` values render recursively.
function Maybe.toString<T>(maybe: Maybe<T>): string
	return Show.value(maybe)
end

--- Calls `f` with a `Just` value for its side effect and returns `maybe` unchanged.
function Maybe.inspect<M>(maybe: M, f: (value: ValueOf<M>) -> ()): M
	local m = view(maybe)
	if m.kind == "Just" then
		f(m.value)
	end
	return maybe
end

--- The first element of a list, or `Nothing` if it is empty.
function Maybe.first<T>(list: { T }): Maybe<T>
	return Maybe.of(list[1])
end

--- The last element of a list, or `Nothing` if it is empty.
function Maybe.last<T>(list: { T }): Maybe<T>
	return Maybe.of(list[#list])
end

--- The first element satisfying `predicate`, or `Nothing`.
function Maybe.find<T>(list: { T }, predicate: (value: T) -> boolean): Maybe<T>
	for _, value in ipairs(list) do
		if predicate(value) then
			return Maybe.just(value)
		end
	end
	return NOTHING
end

--- The entry for `key` in a map, or `Nothing` if it is absent.
function Maybe.get<K, V>(map: { [K]: V }, key: K): Maybe<V>
	return Maybe.of(map[key])
end

--- `Just` of every value in order if all are `Just`; otherwise `Nothing`. (true-myth's `transposeArray`.)
function Maybe.all<M>(maybes: { M }): Maybe<{ ValueOf<M> }>
	local values: { any } = {}
	for _, maybe in ipairs(maybes) do
		local m = view(maybe)
		if m.kind == "Nothing" then
			return NOTHING
		end
		table.insert(values, m.value)
	end
	return Maybe.just(values)
end

--- The values of every `Just`, in order; `Nothing`s are dropped.
function Maybe.values<M>(maybes: { M }): { ValueOf<M> }
	local values: { any } = {}
	for _, maybe in ipairs(maybes) do
		local m = view(maybe)
		if m.kind == "Just" then
			table.insert(values, m.value)
		end
	end
	return values
end

--- Wraps a function that may return nil into one that returns a `Maybe` of its first return value.
function Maybe.safe<T, A...>(f: (A...) -> T): (A...) -> Maybe<NonNil<T>>
	return function(...: A...): Maybe<NonNil<T>>
		return Maybe.of(f(...))
	end
end

return Maybe
