--!strict
local Harness = require("../harness")
local Types = require("../../src/TrueMyth") -- types only: the spec uses `lib`, the build under test

type Lib = typeof(Types)
type Result<T, E> = Types.Result<T, E>

type Shape = { read kind: "Circle", read radius: number } | { read kind: "Square", read side: number }

return function(lib: Lib, t: Harness.T)
	local Exhaustive = lib.Exhaustive

	local function area(shape: Shape): number
		if shape.kind == "Circle" then
			return 3 * shape.radius * shape.radius
		elseif shape.kind == "Square" then
			return shape.side * shape.side
		end
		return Exhaustive.casesHandled(shape)
	end

	t.test("an exhaustive chain type-checks and never reaches casesHandled", function()
		t.equal(area({ kind = "Square", side = 2 }), 4)
		t.equal(area({ kind = "Circle", radius = 1 }), 3)
	end)

	t.test("reaching casesHandled at run time is a defect", function()
		t.raises(function()
			-- SAFETY: deliberately lies to the type checker to simulate data from outside the type system.
			area({ kind = "Triangle" } :: any)
		end, "Exhaustive.casesHandled: unhandled case")
	end)
end
