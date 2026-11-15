---
title: Maybe
description: Make absence explicit with Just and Nothing.
---

A `Maybe<T>` is either `Just<T>` (`{ kind = "Just", value = T }`) or `Nothing` (`{ kind = "Nothing" }`). Use it
wherever a value may be missing and the caller must decide what that means.

## Create

```luau check
local Maybe = TrueMyth.Maybe

local level = Maybe.of(UnitLevel("target")) -- Maybe<number>: Nothing for nil
local name = Maybe.just("Hogger")           -- Just<string>
local none = Maybe.nothing()                -- Nothing, assignable to every Maybe<T>
```

`Maybe.just(nil)` is a defect and raises. Use `Maybe.of` for values that may be nil: it returns `Nothing` for
nil, and its value type has nil removed.

## Narrow

```luau check
local level = Maybe.of(UnitLevel("target"))
-- ---cut---
if level.kind == "Just" then
	print(level.value + 1)   -- fine: narrowed to Just<number>
end
print(level.value)           -- error: Key 'value' is missing from 'Nothing'
```

## Transform

```luau check
local level = Maybe.of(UnitLevel("target"))
-- ---cut---
local nextLevel = Maybe.map(level, function(n: number): number
	return n + 1
end)
local text = Maybe.match(nextLevel, {
	Just = function(n: number): string
		return "level " .. n
	end,
	Nothing = function(): string
		return "no target"
	end,
})
```

`Maybe.match` is exhaustive: leaving out `Nothing` is a type error. `Maybe.andThen` chains steps that may produce
`Nothing`. `Maybe.unwrapOr` and `Maybe.unwrapOrElse` supply a default.

## Lists and maps

```luau check
local quests: { Quest } = {}
local counts: { [number]: number } = {}
local itemId = 6948
local a: number? = 1
local b: number? = nil
-- ---cut---
local first = Maybe.find(quests, function(q: Quest): boolean
	return q.zone == "Elwynn Forest"
end)
local count = Maybe.unwrapOr(Maybe.get(counts, itemId), 0)
local everyLevel = Maybe.all({ Maybe.of(a), Maybe.of(b) }) -- Just({ a, b }) only if both exist
```

`Maybe.get` exists because Luau types `map[key]` as the value type, never nil. Reading through `Maybe.get`
puts the missing case back in the type.

## When to use it

- **At the edges.** Wrap values that may be missing where they enter your code: a lookup in a table, an API that
  can return `nil`, an optional saved setting. Inside, pass plain values around.
- **For "might not exist", not for "went wrong".** If you want to know _why_ something is missing, use a
  [Result](../result/) with a typed error instead.
- **Not for on/off flags.** A `Maybe<boolean>` has three states and reads badly. Use a boolean, or a union of
  string tags such as `"enabled" | "disabled" | "unset"`.

See the [Maybe API](../../api/maybe/) for every function.
