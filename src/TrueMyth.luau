--!strict
--[[
	luau-true-myth: safe, idiomatic optional values, results and tasks for strict Luau.

	Require a single module (`require("./TrueMyth/Result")`) or this entry point for all of them. The types are
	re-exported here: `TrueMyth.Maybe<T>`, `TrueMyth.Result<T, E>`, `TrueMyth.Task<T, E>`.

	Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
]]

local Delay = require("./Delay")
local Exhaustive = require("./Exhaustive")
local Maybe = require("./Maybe")
local Result = require("./Result")
local Task = require("./Task")
local Toolbelt = require("./Toolbelt")

export type Maybe<T> = Maybe.Maybe<T>
export type Just<T> = Maybe.Just<T>
export type Nothing = Maybe.Nothing
export type Result<T, E> = Result.Result<T, E>
export type Ok<T> = Result.Ok<T>
export type Err<E> = Result.Err<E>
export type Task<T, E> = Task.Task<T, E>
export type Deferred<T, E> = Task.Deferred<T, E>
export type Schedule = Task.Schedule
export type Timeout = Task.Timeout
export type RetryStatus = Task.RetryStatus
export type RetryFailed<E> = Task.RetryFailed<E>
export type RetryOptions<E> = Task.RetryOptions<E>
export type Strategy = Delay.Strategy

return {
	--- The library version, matching the git tag without its `v`.
	version = "0.1.0",
	Delay = Delay,
	Exhaustive = Exhaustive,
	Maybe = Maybe,
	Result = Result,
	Task = Task,
	Toolbelt = Toolbelt,
}
