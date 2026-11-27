--!strict
local Task = require("../../packages/true-myth/src/Task")

type Task<T, E> = Task.Task<T, E>

local deferred = Task.withResolvers() :: Task.Deferred<number, string>

deferred.task.state = { kind = "Resolved", value = 1 } -- expect-error: is read-only

deferred.resolve("one") -- expect-error: Expected this to be 'number', but got 'string'

local _ = Task.async(function()
	local result = Task.await(deferred.task)
	local _n: number = result.value -- expect-error: Key 'value' is missing from 'Err<string>'
	return result
end)

local limited = Task.timeout(deferred.task, 5, function(_: number, _: () -> ()) end)
local _onlyString: Task<number, string> = limited -- expect-error: got `Rejected<Timeout | string>`
