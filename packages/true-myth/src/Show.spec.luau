--!strict
local Harness = require("@luau-true-myth/test-harness/Harness")
local Show = require("./Show")
local Types = require("./TrueMyth")

type Lib = typeof(Types)

return Harness.spec(Types, function(_: Lib, t: Harness.T)
	t.test("strings are quoted and escaped", function()
		t.equal(Show.value("a"), '"a"')
		t.equal(Show.value('say "hi"'), '"say \\"hi\\""')
	end)

	t.test("other plain values use tostring", function()
		t.equal(Show.value(1), "1")
		t.equal(Show.value(true), "true")
		t.equal(Show.value(nil), "nil")
	end)

	t.test("each tag renders with its payload field", function()
		t.equal(Show.value({ kind = "Just", value = 1 }), "Just(1)")
		t.equal(Show.value({ kind = "Nothing" }), "Nothing")
		t.equal(Show.value({ kind = "Ok", value = "x" }), 'Ok("x")')
		t.equal(Show.value({ kind = "Err", error = false }), "Err(false)")
	end)

	t.test("nesting renders recursively", function()
		t.equal(
			Show.value({ kind = "Just", value = { kind = "Err", error = { kind = "Nothing" } } }),
			"Just(Err(Nothing))"
		)
	end)

	t.test("tables without a known tag fall back to tostring", function()
		local unknownTag = { kind = "Pending" }
		t.equal(Show.value(unknownTag), tostring(unknownTag))
		local untagged = { 1, 2 }
		t.equal(Show.value(untagged), tostring(untagged))
	end)
end)
