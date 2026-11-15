--!strict
-- Negative fixture: every marked line must produce a type error containing its phrase (new solver).
local Maybe = require("../../src/Maybe")

type Maybe<T> = Maybe.Maybe<T>

local function lookup(key: string): Maybe<number>
	return if key == "a" then Maybe.just(1) else Maybe.nothing()
end

local found = lookup("a")

-- The value exists only on Just: narrow first.
local _value = found.value -- expect-error: Key 'value' is missing from 'Nothing'

-- Variants are read-only.
local _ = function(j: Maybe.Just<number>)
	j.value = 2 -- expect-error: is read-only
end

-- The default must have the value's type.
local _wrong: number = Maybe.unwrapOr(found, "zero") -- expect-error: Expected this to be 'number', but got 'string'

-- `of` strips nil: a Maybe<string> from a string? argument.
local text: string? = nil
local _ofText: Maybe<number> = Maybe.of(text) -- expect-error: is not a subtype of

-- Both handlers are required.
local _ = Maybe.match(found, { -- expect-error: missing field 'Nothing'
	Just = function(n: number): number
		return n
	end,
})

-- A Maybe is not a Result.
local Result = require("../../src/Result")
local _ = Result.unwrapOr(found, 0) -- expect-error: expected a Result
