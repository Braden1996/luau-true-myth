--!strict
local Diagnostics = require("./diagnostics")
local Harness = require("../../packages/test-harness/src/Harness")

return function(t: Harness.T)
	t.test("parse reads file, line, column and message, normalising backslashes", function()
		t.equal(Diagnostics.parse("tests\\fail\\x.luau(3,7): TypeError: bad\n"), {
			{ file = "tests/fail/x.luau", line = 3, column = 7, text = "TypeError: bad" },
		})
	end)

	t.test("parse joins continuation lines and skips log lines", function()
		local output = table.concat({
			"[WARN] No definitions file provided by client",
			"a.luau(1,1): TypeError: Expected this to be",
			"\t'number'",
			"but got 'string'",
			"[INFO] done",
		}, "\n")
		t.equal(Diagnostics.parse(output), {
			{
				file = "a.luau",
				line = 1,
				column = 1,
				text = "TypeError: Expected this to be\n\t'number'\nbut got 'string'",
			},
		})
	end)

	t.test("parse sorts by file, line, column, then message", function()
		local output = table.concat({
			"b.luau(1,1): Z",
			"a.luau(2,5): Y",
			"a.luau(2,1): X",
			"a.luau(2,1): W",
		}, "\n")
		local order = {}
		for _, diagnostic in Diagnostics.parse(output) do
			table.insert(order, diagnostic.text)
		end
		t.equal(order, { "W", "X", "Y", "Z" })
	end)

	t.test("parse handles CRLF and empty output", function()
		t.equal(#Diagnostics.parse("a.luau(1,2): E\r\n"), 1)
		t.equal(Diagnostics.parse(""), {})
	end)

	t.test("render writes line:column: message, one per line", function()
		local rendered = Diagnostics.render({
			{ file = "a", line = 1, column = 2, text = "first" },
			{ file = "a", line = 3, column = 4, text = "second" },
		})
		t.equal(rendered, "1:2: first\n3:4: second\n")
		t.equal(Diagnostics.render({}), "\n")
	end)

	t.test("markers finds expect-error phrases with their line numbers", function()
		local source = table.concat({
			"--!strict",
			"local a = 1 -- expect-error: is read-only",
			"local b = 2",
			"local c = 3 -- expect-error: missing field 'Nothing'   ",
		}, "\n")
		t.equal(Diagnostics.markers(source), {
			{ line = 2, phrase = "is read-only" },
			{ line = 4, phrase = "missing field 'Nothing'" },
		})
	end)

	t.test("unmatchedMarkers needs a diagnostic on the same line containing the phrase", function()
		local markers = { { line = 2, phrase = "read-only" }, { line = 5, phrase = "missing" } }
		local diagnostics = {
			{ file = "f", line = 2, column = 1, text = "Property value is read-only" },
			{ file = "f", line = 4, column = 1, text = "missing field" },
		}
		t.equal(Diagnostics.unmatchedMarkers(markers, diagnostics), { { line = 5, phrase = "missing" } })
	end)

	t.test("unmarkedLines lists each line with a diagnostic but no marker, once", function()
		local markers = { { line = 2, phrase = "x" } }
		local diagnostics = {
			{ file = "f", line = 2, column = 1, text = "x" },
			{ file = "f", line = 7, column = 1, text = "y" },
			{ file = "f", line = 7, column = 9, text = "z" },
		}
		t.equal(Diagnostics.unmarkedLines(markers, diagnostics), { 7 })
	end)
end
