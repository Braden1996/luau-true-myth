--!strict
-- Negative fixture: every marked line must produce a type error containing its phrase (new solver).
local Task = require("../../src/Task")

type Task<T, E> = Task.Task<T, E>

-- Luau cannot infer a generic used only in the result, so name the types with a cast.
local deferred = Task.withResolvers() :: Task.Deferred<number, string>

-- The state is read-only: settle through the resolvers.
deferred.task.state = { kind = "Resolved", value = 1 } -- expect-error: is read-only

-- Resolvers take the declared types.
deferred.resolve("one") -- expect-error: Expected this to be 'number', but got 'string'

-- `await` returns a Result: narrow before using the value.
local _ = Task.async(function()
	local result = Task.await(deferred.task)
	local _n: number = result.value -- expect-error: Key 'value' is missing from 'Err<string>'
	return result
end)

-- A timeout adds Timeout to the rejection type.
local limited = Task.timeout(deferred.task, 5, function(_: number, _: () -> ()) end)
local _onlyString: Task<number, string> = limited -- expect-error: got `Rejected<Timeout | string>`
