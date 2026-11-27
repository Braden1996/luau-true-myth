--!strict
local Harness = require("../../packages/test-harness/src/Harness")
local Rules = require("./rules")

local function messagesFor(path: string, lines: { string }): { string }
	local messages = {}
	for _, problem in Rules.check(path, table.concat(lines, "\n")) do
		table.insert(messages, problem.line .. ": " .. problem.message)
	end
	return messages
end

return function(t: Harness.T)
	t.test("fileKind classifies shipped code, specs, fixtures and tooling", function()
		t.equal(Rules.fileKind("src/Result.luau"), "shipped")
		t.equal(Rules.fileKind("wow/TrueMyth.luau"), "shipped")
		t.equal(Rules.fileKind("src/Result.spec.luau"), "spec")
		t.equal(Rules.fileKind("scripts/lint/rules.spec.luau"), "spec")
		t.equal(Rules.fileKind("tests/fail/maybe.luau"), "fixture")
		t.equal(Rules.fileKind("tests/pass/usage.luau"), "fixture")
		t.equal(Rules.fileKind("scripts/build.luau"), "tooling")
	end)

	t.test("commentStart ignores dashes inside strings", function()
		t.equal(Rules.commentStart('print("--not a comment")'), nil)
		t.equal(Rules.commentStart("print('--') -- real"), 13)
		t.equal(Rules.commentStart("local x = 1 -- note"), 13)
		t.equal(Rules.commentStart("local x = 1"), nil)
	end)

	t.test("codeOf drops the comment and blanks string contents", function()
		t.equal(Rules.codeOf('local s = "a -- b" -- c'), 'local s = "      " ')
		t.equal(Rules.codeOf("return x"), "return x")
	end)

	t.test("isAllowedComment allows only directives and fixture markers", function()
		t.equal(Rules.isAllowedComment("--!strict", "shipped"), true)
		t.equal(Rules.isAllowedComment("local x = 1", "shipped"), true)
		t.equal(Rules.isAllowedComment("-- explains things", "tooling"), false)
		t.equal(Rules.isAllowedComment("x = 1 -- expect-error: read-only", "fixture"), true)
		t.equal(Rules.isAllowedComment("x = 1 -- expect-error: read-only", "spec"), false)
		t.equal(Rules.isAllowedComment("x = 1 -- note", "fixture"), false)
	end)

	t.test("weakensChecking flags nonstrict and nocheck", function()
		t.equal(Rules.weakensChecking("--!nonstrict"), true)
		t.equal(Rules.weakensChecking("--!nocheck"), true)
		t.equal(Rules.weakensChecking("--!strict"), false)
	end)

	t.test("luauOnlyCall finds library functions Lua 5.1 lacks", function()
		t.equal(Rules.luauOnlyCall("local copy = table.clone(t)"), "table.clone")
		t.equal(Rules.luauOnlyCall("local parts = string.split(s, ',')"), "string.split")
		t.equal(Rules.luauOnlyCall("local x = bit32.band(a, b)"), "bit32.")
		t.equal(Rules.luauOnlyCall("table.insert(t, v)"), nil)
	end)

	t.test("isGeneralizedIteration flags `for ... in t do` but not iterator calls", function()
		t.equal(Rules.isGeneralizedIteration("for _, v in values do"), true)
		t.equal(Rules.isGeneralizedIteration("for key, value in record do"), true)
		t.equal(Rules.isGeneralizedIteration("for _, v in ipairs(values) do"), false)
		t.equal(Rules.isGeneralizedIteration("for k, v in pairs(record) do"), false)
		t.equal(Rules.isGeneralizedIteration("for line in string.gmatch(s, '.') do"), false)
		t.equal(Rules.isGeneralizedIteration("for i = 1, 10 do"), false)
	end)

	t.test("isGenericLocalFunction flags local helpers with type parameters", function()
		t.equal(Rules.isGenericLocalFunction("local function settle<T>(x: T)"), true)
		t.equal(Rules.isGenericLocalFunction("local function settle(x: unknown)"), false)
		t.equal(Rules.isGenericLocalFunction("function Result.map<R, U>(result: R)"), false)
	end)

	t.test("declaredFunctionName reads local and module functions", function()
		t.equal(Rules.declaredFunctionName("local function uncheckedView(x)"), "uncheckedView")
		t.equal(Rules.declaredFunctionName("function Task.withRetries<K>("), "withRetries")
		t.equal(Rules.declaredFunctionName("function Result.map<R, U>(result: R)"), "map")
		t.equal(Rules.declaredFunctionName("local x = 1"), nil)
	end)

	t.test("check requires the strict header", function()
		t.equal(messagesFor("scripts/x.luau", { "local x = 1" }), { "1: must start with --!strict" })
		t.equal(messagesFor("scripts/x.luau", { "--!strict", "local x = 1" }), {})
	end)

	t.test("check rejects comments and block comments", function()
		t.equal(messagesFor("scripts/x.luau", { "--!strict", "-- why", "local x = 1 -- what" }), {
			"2: comment: use a descriptive name, a smaller function or a test instead",
			"3: comment: use a descriptive name, a smaller function or a test instead",
		})
		t.equal(
			messagesFor("scripts/x.luau", { "--!strict", "--[[", "]]" })[1],
			"2: block comment: name things instead"
		)
	end)

	t.test("check allows casts only inside unchecked functions", function()
		t.equal(
			messagesFor("src/X.luau", {
				"--!strict",
				"local function uncheckedView(x: unknown): any",
				"\treturn x :: any",
				"end",
			}),
			{}
		)
		t.equal(
			messagesFor(
				"src/X.luau",
				{ "--!strict", "local function view(x: unknown): any", "\treturn x :: any", "end" }
			),
			{ "3: `:: any` outside a function named unchecked..." }
		)
	end)

	t.test("check applies Lua 5.1 rules to shipped code only, outside type functions", function()
		local shipped = {
			"--!strict",
			"local copy = table.clone(t)",
			"for _, v in values do end",
			"local s = `{x}`",
			"type function Strip(t: type): type",
			"\tfor _, c in t:components() do end",
			"end",
		}
		t.equal(messagesFor("src/X.luau", shipped), {
			"2: table.clone does not exist in Lua 5.1 (WoW)",
			"3: generalized iteration: use pairs() or ipairs() (Lua 5.1 has no __iter)",
			"4: string interpolation: use .. or string.format",
		})
		t.equal(messagesFor("src/X.spec.luau", shipped), {})
		t.equal(messagesFor("scripts/x.luau", shipped), {})
	end)
end
