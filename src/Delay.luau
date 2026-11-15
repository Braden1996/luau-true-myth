--!strict
--[[
	Delay: retry delay strategies for `Task.withRetries`.

	A `Strategy` is an iterator: each call returns the next delay in seconds, or nil when no retries remain. Every
	constructor returns a fresh strategy; the infinite ones are usually capped with `Delay.take`. Delays are in
	seconds (as `C_Timer.After` and Lune's `task.delay` take them), not true-myth's milliseconds.

	Pure: no clock and no randomness of its own (`Delay.jitter` takes the random source as an argument).

	Ported from true-myth (MIT, Chris Krycho and contributors): https://github.com/true-myth/true-myth
]]

--- The next delay in seconds, or nil when no retries remain.
export type Strategy = () -> number?

export type ExponentialOptions = {
	--- The first delay, in seconds. Default 1.
	read from: number?,
	--- The growth factor. Default 2. Below 1 the delays shrink, which is rarely wanted.
	read factor: number?,
	--- The largest delay, in seconds. Default: unbounded.
	read max: number?,
}

export type LinearOptions = {
	--- The first delay, in seconds. Default 0.
	read from: number?,
	--- Added to each following delay, in seconds. Default 1.
	read step: number?,
}

local Delay = {}

--- `seconds` forever.
function Delay.fixed(seconds: number): Strategy
	return function(): number?
		return seconds
	end
end

--- 0 seconds forever: retry at once.
function Delay.immediate(): Strategy
	return Delay.fixed(0)
end

--- No retries.
function Delay.none(): Strategy
	return function(): number?
		return nil
	end
end

--- `from`, `from * factor`, `from * factor^2`, ... capped at `max`.
function Delay.exponential(options: ExponentialOptions?): Strategy
	local from = if options and options.from then options.from else 1
	local factor = if options and options.factor then options.factor else 2
	local max = if options and options.max then options.max else math.huge
	local current = from
	return function(): number?
		local delay = math.min(current, max)
		current = current * factor
		return delay
	end
end

--- `from`, `from`, `2 * from`, `3 * from`, `5 * from`, ... (the Fibonacci sequence scaled by `from`, default 1).
function Delay.fibonacci(from: number?): Strategy
	local base = from or 1
	local current, following = base, base
	return function(): number?
		local delay = current
		current, following = following, current + following
		return delay
	end
end

--- `from`, `from + step`, `from + 2 * step`, ...
function Delay.linear(options: LinearOptions?): Strategy
	local from = if options and options.from then options.from else 0
	local step = if options and options.step then options.step else 1
	local current = from
	return function(): number?
		local delay = current
		current = current + step
		return delay
	end
end

--- At most `count` delays from `strategy`.
function Delay.take(strategy: Strategy, count: number): Strategy
	local taken = 0
	return function(): number?
		if taken >= count then
			return nil
		end
		taken = taken + 1
		return strategy()
	end
end

--- Each delay from `strategy` scaled by a random factor in [0, 1): "full jitter". `random` is the source, for
--- example `math.random`; pass a deterministic one in tests.
function Delay.jitter(strategy: Strategy, random: () -> number): Strategy
	return function(): number?
		local delay = strategy()
		if delay == nil then
			return nil
		end
		return delay * random()
	end
end

return Delay
