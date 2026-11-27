--!strict
local Exhaustive = {}

function Exhaustive.casesHandled(value: never): never
	error("Exhaustive.casesHandled: unhandled case " .. tostring(value), 2)
end

return Exhaustive
