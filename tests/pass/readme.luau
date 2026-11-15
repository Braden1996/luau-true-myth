--!strict
-- Positive fixture: the README's examples, with stand-ins for the host APIs they use. Must type-check clean.
local TrueMyth = require("../../src/TrueMyth")

local Maybe, Result, Task = TrueMyth.Maybe, TrueMyth.Result, TrueMyth.Task
type Result<T, E> = TrueMyth.Result<T, E>
type Task<T, E> = TrueMyth.Task<T, E>

type Quest = { read title: string, read zone: string }
type NotFound = { read kind: "NotFound", read id: number }
type Invalid = { read kind: "Invalid", read reason: string }
type LookupError = NotFound | Invalid
type ParseError = { read kind: "ParseError", read message: string }
type MigrationError = { read kind: "MigrationError", read from: number }
type Settings = { read version: number }

-- Stand-ins for host APIs and data.
local QUESTS: { [number]: Quest } = { [42] = { title = "A Threat Within", zone = "Elwynn Forest" } }
local quests: { Quest } = { QUESTS[42] }
local counts: { [number]: number } = {}
local itemId = 2589
local raw = "{}"
local function UnitLevel(_: string): number?
	return nil
end
local function decode(text: string): { [string]: unknown }
	return { text = text }
end
local function migrate(_: { [string]: unknown }): Result<Settings, MigrationError>
	return Result.ok({ version = 2 })
end
local schedule = function(_: number, f: () -> ())
	f()
end

-- Quick example.
local function findQuest(id: number): Result<Quest, NotFound>
	local quest = QUESTS[id]
	if quest == nil then
		return Result.err({ kind = "NotFound", id = id } :: NotFound)
	end
	return Result.ok(quest)
end
local found = findQuest(42)
if found.kind == "Ok" then
	print(found.value.title)
end
local title: string = Result.mapOr(findQuest(7), "?", function(q: Quest): string
	return q.title
end)

-- Maybe.
local level = Maybe.of(UnitLevel("target"))
local nextLevel = Maybe.map(level, function(n: number): number
	return n + 1
end)
local text: string = Maybe.match(nextLevel, {
	Just = function(n: number): string
		return "level " .. n
	end,
	Nothing = function(): string
		return "no target"
	end,
})
local first: TrueMyth.Maybe<Quest> = Maybe.find(quests, function(q: Quest): boolean
	return q.zone == "Elwynn Forest"
end)
local count: number = Maybe.unwrapOr(Maybe.get(counts, itemId), 0)

-- Result.
local parse = Result.safe(decode, function(raised: unknown): ParseError
	return { kind = "ParseError", message = tostring(raised) }
end)
local saved: Result<Settings, ParseError | MigrationError> = Result.andThen(parse(raw), migrate)
local all: Result<{ Quest }, NotFound> = Result.all({ findQuest(1), findQuest(2) })
local found2, missing = Result.partition({ findQuest(1), findQuest(2) })
local _q: { Quest }, _m: { NotFound } = found2, missing

-- Exhaustive matching.
local function describe(e: LookupError): string
	if e.kind == "NotFound" then
		return "no quest " .. e.id
	elseif e.kind == "Invalid" then
		return e.reason
	end
	return TrueMyth.Exhaustive.casesHandled(e)
end

-- Task.
local function fetchQuest(id: number): Task<Quest, NotFound>
	return Task.new(function(resolve: (Quest) -> (), reject: (NotFound) -> ())
		local quest = QUESTS[id]
		if quest then
			resolve(quest)
		else
			reject({ kind = "NotFound", id = id })
		end
	end)
end
local summary: Task<string, NotFound | TrueMyth.Timeout> = Task.async(
	function(): Result<string, NotFound | TrueMyth.Timeout>
		local quest = Task.await(Task.timeout(fetchQuest(42), 5, schedule))
		if quest.kind == "Err" then
			return quest
		end
		return Result.ok(quest.value.title)
	end
)
local retried: Task<Quest, TrueMyth.RetryFailed<NotFound>> = Task.withRetries(
	function(_: TrueMyth.RetryStatus): Task<Quest, NotFound>
		return fetchQuest(42)
	end,
	{
		strategy = TrueMyth.Delay.take(TrueMyth.Delay.exponential({ from = 0.5 }), 4),
		schedule = schedule,
	}
)

print(title, text, first, count, saved, all, describe, summary, retried)
