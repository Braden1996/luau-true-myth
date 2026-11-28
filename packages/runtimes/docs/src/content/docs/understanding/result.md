---
title: Result
description: Return failures as typed values instead of raising them.
---

A `Result<T, E>` is either `Ok<T>` (`{ kind = "Ok", value = T }`) or `Err<E>` (`{ kind = "Err", error = E }`).
Return one from every operation that can fail in a known way. Reserve `error()` for defects.

## Typed errors

Make errors tagged tables, so callers can tell them apart and the checker can tell when one is unhandled:

```luau check
type Result<T, E> = Result.Result<T, E>
-- ---cut---
type NotFound = { read kind: "NotFound", read id: number }
type Invalid = { read kind: "Invalid", read reason: string }
type LookupError = NotFound | Invalid

local function findQuest(id: number): Result<Quest, LookupError>
	if id <= 0 then
		return Result.err({ kind = "Invalid", reason = "id must be positive" } :: Invalid)
	end
	local quest = QUESTS[id]
	if quest == nil then
		return Result.err({ kind = "NotFound", id = id } :: NotFound)
	end
	return Result.ok(quest)
end
```

`Result.ok(quest)` is an `Ok<Quest>` and fits any `Result<Quest, E>`, so the constructors need no annotations.
The `:: Invalid` casts tell Luau which variant a table literal is. They are checked, not unsafe.

## Chain

```luau check
type NotFound = { read kind: "NotFound", read id: number }
local function findQuest(id: number): Result.Result<Quest, NotFound>
	return if QUESTS[id] then Result.ok(QUESTS[id]) else Result.err({ kind = "NotFound", id = id } :: NotFound)
end
type ParseError = { read kind: "ParseError", read message: string }
type MigrationError = { read kind: "MigrationError", read from: number }
type Settings = { version: number, volume: number }
local raw = "{}"
local function parse(text: string): Result.Result<{ version: number }, ParseError>
	return Result.ok({ version = #text })
end
local function migrate(data: { version: number }): Result.Result<Settings, MigrationError>
	return Result.ok({ version = data.version, volume = 1 })
end
-- ---cut---
local saved = Result.andThen(parse(raw), migrate)      -- Result<Settings, ParseError | MigrationError>
local title = Result.mapOr(findQuest(7), "?", function(q: Quest): string
	return q.title
end)
```

`Result.andThen` adds the error types of each step, so a pipeline's error type lists exactly the failures it can
produce.

## Lists

```luau check
type NotFound = { read kind: "NotFound", read id: number }
local function findQuest(id: number): Result.Result<Quest, NotFound>
	return if QUESTS[id] then Result.ok(QUESTS[id]) else Result.err({ kind = "NotFound", id = id } :: NotFound)
end
local lookups: { Result.Result<Quest, NotFound> } = { findQuest(3) }
local id = 7
local function fromCache(id: number): Result.Result<Quest, string>
	return Result.err("not cached")
end
local function fromServer(id: number): Result.Result<Quest, string>
	return Result.err("offline")
end
-- ---cut---
local all = Result.all({ findQuest(1), findQuest(2) })    -- Ok of every quest, or the first error
local quests, missing = Result.partition(lookups)         -- ({ Quest }, { LookupError })
local any = Result.any({ fromCache(id), fromServer(id) }) -- the first Ok, or every error
```

## At the boundary with code that raises

WoW APIs, string parsing and third-party Lua can raise. Wrap them once, where they enter your code, and turn the
raised value into a typed error:

```luau check
type ParseError = { kind: "ParseError", message: string }
local function decode(text: string): { [string]: unknown }
	return { text = text }
end
-- ---cut---
local parse = Result.safe(decode, function(raised: unknown): ParseError
	return { kind = "ParseError", message = tostring(raised) }
end)
```

`Result.tryOr` and `Result.tryOrElse` do the same for a single call.

## When to use it

- **For every failure you expect.** Missing data, bad input, a request that was refused: return a `Result`. Keep
  `error()` for real bugs, like a broken invariant.
- **With specific error types.** A union of small tagged tables (`NotFound | Invalid`) tells callers exactly what
  can happen. A plain string error tells them almost nothing.
- **At the edge with code that raises.** Wrap it once with `Result.safe` or `Result.tryOrElse`, so the rest of your
  code never needs `pcall`.

See the [Result API](../../api/result/) for every function, and [Exhaustive matching](../exhaustive-matching/) for
handling every error variant.
