--!strict
-- Internal: renders values for `toString`, so nested `Maybe`/`Result` values print readably:
-- `Just(Ok("x"))`. Not part of the public API.

local Show = {}

local function isTagged(value: unknown, kind: string): boolean
	-- SAFETY: rawget only runs once `type(value) == "table"` holds; a missing field reads as nil.
	return type(value) == "table" and rawget(value :: any, "kind") == kind
end

--- Renders `value`: strings quoted, `Just`/`Nothing`/`Ok`/`Err` recursively, anything else with `tostring`.
function Show.value(value: unknown): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) == "table" then
		-- SAFETY: only read through rawget after `type(value) == "table"`; a missing field is nil.
		local t = value :: any
		if isTagged(t, "Just") then
			return "Just(" .. Show.value(rawget(t, "value")) .. ")"
		elseif isTagged(t, "Nothing") then
			return "Nothing"
		elseif isTagged(t, "Ok") then
			return "Ok(" .. Show.value(rawget(t, "value")) .. ")"
		elseif isTagged(t, "Err") then
			return "Err(" .. Show.value(rawget(t, "error")) .. ")"
		end
	end
	return tostring(value)
end

return Show
