--!strict
--[[
	Exhaustive: compile-time exhaustiveness for tagged unions.

	Luau does not check that an `if`/`elseif` chain over a union's `kind` covers every variant. Ending the chain with
	`return Exhaustive.casesHandled(value)` makes it: once every variant is handled, `value` is refined to `never`
	and the call type-checks; when a variant is missing (or a new one is added), the call is a type error naming it.
	Reaching it at run time is a defect, so it raises.
]]

local Exhaustive = {}

--- Ends an exhaustive `if`/`elseif` chain. Type error if a variant is unhandled; raises if reached at run time.
function Exhaustive.casesHandled(value: never): never
	error("Exhaustive.casesHandled: unhandled case " .. tostring(value), 2)
end

return Exhaustive
