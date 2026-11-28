--!strict
local Harness = require("../../test-harness/src/Harness")
local Types = require("./TrueMyth")

type Lib = typeof(Types)

return Harness.spec(Types, function(lib: Lib, t: Harness.T)
	local Delay = lib.Delay

	local function collect(strategy: Types.Strategy, count: number): { number }
		local out = {}
		for _ = 1, count do
			local delay = strategy()
			if delay == nil then
				break
			end
			table.insert(out, delay)
		end
		return out
	end

	t.test("fixed, immediate and none", function()
		t.equal(collect(Delay.fixed(2), 3), { 2, 2, 2 })
		t.equal(collect(Delay.immediate(), 3), { 0, 0, 0 })
		t.equal(collect(Delay.none(), 3), {})
	end)

	t.test("exponential", function()
		t.equal(collect(Delay.exponential(), 4), { 1, 2, 4, 8 })
		t.equal(collect(Delay.exponential({ from = 0.5, factor = 3 }), 3), { 0.5, 1.5, 4.5 })
		t.equal(collect(Delay.exponential({ from = 1, max = 5 }), 5), { 1, 2, 4, 5, 5 })
	end)

	t.test("fibonacci", function()
		t.equal(collect(Delay.fibonacci(), 7), { 1, 1, 2, 3, 5, 8, 13 })
		t.equal(collect(Delay.fibonacci(2), 4), { 2, 2, 4, 6 })
	end)

	t.test("linear", function()
		t.equal(collect(Delay.linear(), 3), { 0, 1, 2 })
		t.equal(collect(Delay.linear({ from = 1, step = 0.5 }), 3), { 1, 1.5, 2 })
	end)

	t.test("take caps a strategy", function()
		t.equal(collect(Delay.take(Delay.fixed(1), 2), 5), { 1, 1 })
		t.equal(collect(Delay.take(Delay.fixed(1), 0), 5), {})
	end)

	t.test("jitter scales by the random source", function()
		t.equal(
			collect(
				Delay.jitter(Delay.fixed(10), function(): number
					return 0.5
				end),
				2
			),
			{ 5, 5 }
		)
		t.equal(
			collect(
				Delay.jitter(Delay.none(), function(): number
					return math.random()
				end),
				2
			),
			{}
		)
	end)

	t.test("each call returns a fresh strategy", function()
		local a, b = Delay.exponential(), Delay.exponential()
		a()
		a()
		t.equal(b(), 1)
	end)
end)
