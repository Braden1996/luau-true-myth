--!strict
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
	version = "0.2.0",
	Delay = Delay,
	Exhaustive = Exhaustive,
	Maybe = Maybe,
	Result = Result,
	Task = Task,
	Toolbelt = Toolbelt,
}
