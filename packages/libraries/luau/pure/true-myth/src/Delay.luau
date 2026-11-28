--!strict
export type Strategy = () -> number?

export type ExponentialOptions = {
	read from: number?,
	read factor: number?,
	read max: number?,
}

export type LinearOptions = {
	read from: number?,
	read step: number?,
}

local Delay = {}

function Delay.fixed(seconds: number): Strategy
	return function(): number?
		return seconds
	end
end

function Delay.immediate(): Strategy
	return Delay.fixed(0)
end

function Delay.none(): Strategy
	return function(): number?
		return nil
	end
end

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

function Delay.fibonacci(from: number?): Strategy
	local base = from or 1
	local current, following = base, base
	return function(): number?
		local delay = current
		current, following = following, current + following
		return delay
	end
end

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
