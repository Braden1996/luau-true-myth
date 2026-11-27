--!strict
local Maybe = require("../../packages/true-myth/src/Maybe")

type Maybe<T> = Maybe.Maybe<T>

local function lookup(key: string): Maybe<number>
	return if key == "a" then Maybe.just(1) else Maybe.nothing()
end

local found = lookup("a")

local _value = found.value -- expect-error: Key 'value' is missing from 'Nothing'

local _ = function(j: Maybe.Just<number>)
	j.value = 2 -- expect-error: is read-only
end

local _wrong: number = Maybe.unwrapOr(found, "zero") -- expect-error: Expected this to be 'number', but got 'string'

local text: string? = nil
local _ofText: Maybe<number> = Maybe.of(text) -- expect-error: is not a subtype of

local _ = Maybe.match(found, { -- expect-error: missing field 'Nothing'
	Just = function(n: number): number
		return n
	end,
})

local Result = require("../../packages/true-myth/src/Result")
local _ = Result.unwrapOr(found, 0) -- expect-error: expected a Result
