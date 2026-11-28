--!strict
local TrueMyth = require("@luau-true-myth/true-myth/TrueMyth")

local _, namespace = ...
if type(namespace) == "table" then
	namespace.TrueMyth = TrueMyth
end

return TrueMyth
