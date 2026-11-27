--!strict
local Show = require("./Show")

export type Just<T> = { read kind: "Just", read value: T }
export type Nothing = { read kind: "Nothing" }
export type Maybe<T> = Just<T> | Nothing

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

export type Matcher<T, A> = { read Just: (value: T) -> A, read Nothing: () -> A }

local NOTHING: Nothing = { kind = "Nothing" }

local Maybe = {}

local function uncheckedJustOfNonNil(value: unknown): Just<any>
	return { kind = "Just", value = value :: any }
end

local function uncheckedView(maybe: unknown): Maybe<any>
	return maybe :: any
end

function Maybe.just<T>(value: T): Just<T>
	if value == nil then
		error("Maybe.just: value is nil; use Maybe.of for a value that may be nil", 2)
	end
	return { kind = "Just", value = value }
end

function Maybe.nothing(): Nothing
	return NOTHING
end

function Maybe.of<T>(value: T): Maybe<NonNil<T>>
	if value == nil then
		return NOTHING
	end
	return uncheckedJustOfNonNil(value)
end

function Maybe.isJust<T>(maybe: Maybe<T>): boolean
	return maybe.kind == "Just"
end

function Maybe.isNothing<T>(maybe: Maybe<T>): boolean
	return maybe.kind == "Nothing"
end

function Maybe.map<M, U>(maybe: M, f: (value: ValueOf<M>) -> U): Maybe<NonNil<U>>
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return Maybe.of(f(m.value))
	end
	return NOTHING
end

function Maybe.mapOr<M, U>(maybe: M, default: U, f: (value: ValueOf<M>) -> U): U
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return f(m.value)
	end
	return default
end

function Maybe.mapOrElse<M, U>(maybe: M, orElse: () -> U, f: (value: ValueOf<M>) -> U): U
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return f(m.value)
	end
	return orElse()
end

function Maybe.match<M, A>(maybe: M, matcher: Matcher<ValueOf<M>, A>): A
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return matcher.Just(m.value)
	end
	return matcher.Nothing()
end

function Maybe.andThen<M, N>(maybe: M, f: (value: ValueOf<M>) -> N): Maybe<ValueOf<N>>
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return uncheckedView(f(m.value))
	end
	return NOTHING
end

function Maybe.and_<M, N>(maybe: M, other: N): Maybe<ValueOf<N>>
	if uncheckedView(maybe).kind == "Just" then
		return uncheckedView(other)
	end
	return NOTHING
end

function Maybe.or_<M, N>(maybe: M, other: N): Maybe<ValueOf<M> | ValueOf<N>>
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return m
	end
	return uncheckedView(other)
end

function Maybe.orElse<M, N>(maybe: M, f: () -> N): Maybe<ValueOf<M> | ValueOf<N>>
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return m
	end
	return uncheckedView(f())
end

function Maybe.unwrapOr<M>(maybe: M, default: ValueOf<M>): ValueOf<M>
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return m.value
	end
	return default
end

function Maybe.unwrapOrElse<M>(maybe: M, f: () -> ValueOf<M>): ValueOf<M>
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return m.value
	end
	return f()
end

function Maybe.flatten<M>(maybe: M): Maybe<ValueOf<ValueOf<M>>>
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		return uncheckedView(m.value)
	end
	return NOTHING
end

function Maybe.filter<M>(maybe: M, predicate: (value: ValueOf<M>) -> boolean): Maybe<ValueOf<M>>
	local m = uncheckedView(maybe)
	if m.kind == "Just" and predicate(m.value) then
		return m
	end
	return NOTHING
end

function Maybe.equals<T>(a: Maybe<T>, b: Maybe<T>): boolean
	if a.kind == "Just" and b.kind == "Just" then
		return a.value == b.value
	end
	return a.kind == b.kind
end

function Maybe.toString<T>(maybe: Maybe<T>): string
	return Show.value(maybe)
end

function Maybe.inspect<M>(maybe: M, f: (value: ValueOf<M>) -> ()): M
	local m = uncheckedView(maybe)
	if m.kind == "Just" then
		f(m.value)
	end
	return maybe
end

function Maybe.first<T>(list: { T }): Maybe<T>
	return Maybe.of(list[1])
end

function Maybe.last<T>(list: { T }): Maybe<T>
	return Maybe.of(list[#list])
end

function Maybe.find<T>(list: { T }, predicate: (value: T) -> boolean): Maybe<T>
	for _, value in ipairs(list) do
		if predicate(value) then
			return Maybe.just(value)
		end
	end
	return NOTHING
end

function Maybe.get<K, V>(map: { [K]: V }, key: K): Maybe<V>
	return Maybe.of(map[key])
end

function Maybe.all<M>(maybes: { M }): Maybe<{ ValueOf<M> }>
	local values: { any } = {}
	for _, maybe in ipairs(maybes) do
		local m = uncheckedView(maybe)
		if m.kind == "Nothing" then
			return NOTHING
		end
		table.insert(values, m.value)
	end
	return Maybe.just(values)
end

function Maybe.values<M>(maybes: { M }): { ValueOf<M> }
	local values: { any } = {}
	for _, maybe in ipairs(maybes) do
		local m = uncheckedView(maybe)
		if m.kind == "Just" then
			table.insert(values, m.value)
		end
	end
	return values
end

function Maybe.safe<T, A...>(f: (A...) -> T): (A...) -> Maybe<NonNil<T>>
	return function(...: A...): Maybe<NonNil<T>>
		return Maybe.of(f(...))
	end
end

return Maybe
