--!strict
-- The WoW entry point of the Lua 5.1 bundle (`dist/TrueMyth.lua`). Listed in a .toc, the file receives the addon's
-- name and private namespace table and stores the library as `ns.TrueMyth`. Loaded any other way (`dofile`,
-- `require`), it returns the library. Either way it creates no global.
local TrueMyth = require("../src/TrueMyth")

local _, namespace = ...
if type(namespace) == "table" then
	namespace.TrueMyth = TrueMyth
end

return TrueMyth
