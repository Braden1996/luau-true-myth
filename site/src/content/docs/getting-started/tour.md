---
title: Tour
description: Maybe, Result and Task in five minutes.
---

A quick look at the three types. Each has its own page under **Understanding** with the details.

```luau
local TrueMyth = require("./vendor/luau-true-myth/src/TrueMyth")
local Maybe, Result, Task = TrueMyth.Maybe, TrueMyth.Result, TrueMyth.Task
```

## Maybe: a value that might not be there

```luau
local target = Maybe.of(UnitName("target")) -- Just("Hogger") or Nothing

local greeting = Maybe.match(target, {
	Just = function(name: string): string
		return "Hello, " .. name
	end,
	Nothing = function(): string
		return "No target"
	end,
})
```

You cannot get the name out without saying what happens when there is none. [More on Maybe](../../understanding/maybe/).

## Result: an operation that can fail

```luau
type NotFound = { read kind: "NotFound", read id: number }

local function findQuest(id: number): Result.Result<Quest, NotFound>
	local quest = QUESTS[id]
	if quest == nil then
		return Result.err({ kind = "NotFound", id = id } :: NotFound)
	end
	return Result.ok(quest)
end

local title = Result.mapOr(findQuest(42), "Unknown quest", function(quest: Quest): string
	return quest.title
end)
```

The failure is part of the function's type, so every caller knows it can happen. [More on Result](../../understanding/result/).

## Task: a result that arrives later

```luau
local summary = Task.async(function(): Result.Result<string, NotFound>
	local quest = Task.await(fetchQuest(42))
	if quest.kind == "Err" then
		return quest
	end
	return Result.ok(quest.value.title)
end)
```

`Task.await` pauses until the quest arrives, then hands back a `Result`. No callbacks to forget, and no error that
disappears. [More on Task](../../understanding/task/).

## Handling every case

```luau
local function describe(e: LookupError): string
	if e.kind == "NotFound" then
		return "No quest " .. e.id
	elseif e.kind == "Invalid" then
		return e.reason
	end
	return TrueMyth.Exhaustive.casesHandled(e)
end
```

Add a new kind of error later and forget it here, and the type checker points at this line.
[More on exhaustive matching](../../understanding/exhaustive-matching/).
