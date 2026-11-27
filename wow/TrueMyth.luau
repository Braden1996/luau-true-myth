--!strict
local TrueMyth = require("../packages/true-myth/src/TrueMyth")

local _, namespace = ...
if type(namespace) == "table" then
	namespace.TrueMyth = TrueMyth
end

return TrueMyth
