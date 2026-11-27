--!strict

local Rules = {}

export type Problem = { line: number, message: string }

export type FileKind = "shipped" | "spec" | "tooling" | "fixture"

local LUAU_ONLY_LIBRARY = {
	"table.clone",
	"table.create",
	"table.find",
	"table.freeze",
	"table.isfrozen",
	"table.move",
	"table.clear",
	"table.pack",
	"table.unpack",
	"table.maxn",
	"string.split",
	"string.pack",
	"string.unpack",
	"math.clamp",
	"math.sign",
	"math.round",
	"math.noise",
	"math.lerp",
	"math.map",
	"bit32.",
	"buffer.",
	"utf8.",
	"vector.",
	"typeof(",
}

local FIXTURE_MARKER = "-- expect-error:"

function Rules.fileKind(path: string): FileKind
	if string.match(path, "%.spec%.luau$") then
		return "spec"
	elseif string.match(path, "^tests/pass/") or string.match(path, "^tests/fail/") then
		return "fixture"
	elseif
		string.match(path, "^packages/true%-myth/src/")
		or string.match(path, "^src/")
		or string.match(path, "^wow/")
	then
		return "shipped"
	end
	return "tooling"
end

local function blankQuoted(text: string, quote: string): string
	return (
		string.gsub(text, quote .. "([^" .. quote .. "]*)" .. quote, function(inside: string): string
			return quote .. string.rep(" ", #inside) .. quote
		end)
	)
end

function Rules.withoutStringContents(line: string): string
	return blankQuoted(blankQuoted(blankQuoted(line, '"'), "'"), "`")
end

function Rules.commentStart(line: string): number?
	local start = string.find(Rules.withoutStringContents(line), "--", 1, true)
	return start
end

function Rules.codeOf(line: string): string
	local start = Rules.commentStart(line)
	local withoutStrings = Rules.withoutStringContents(line)
	if start == nil then
		return withoutStrings
	end
	return string.sub(withoutStrings, 1, start - 1)
end

function Rules.isDirective(line: string): boolean
	return string.match(line, "^%-%-!") ~= nil
end

function Rules.weakensChecking(line: string): boolean
	return string.match(line, "^%-%-!nonstrict") ~= nil or string.match(line, "^%-%-!nocheck") ~= nil
end

function Rules.isAllowedComment(line: string, kind: FileKind): boolean
	local start = Rules.commentStart(line)
	if start == nil then
		return true
	end
	local comment = string.sub(Rules.withoutStringContents(line), start)
	if start == 1 and Rules.isDirective(line) then
		return true
	end
	return kind == "fixture" and string.sub(comment, 1, #FIXTURE_MARKER) == FIXTURE_MARKER
end

function Rules.luauOnlyCall(code: string): string?
	for _, name in ipairs(LUAU_ONLY_LIBRARY) do
		if string.find(code, name, 1, true) then
			return name
		end
	end
	return nil
end

function Rules.isGeneralizedIteration(code: string): boolean
	return string.match(code, "^%s*for%s.-%sin%s") ~= nil and string.match(code, "%sin%s+[%w_.:]+%(") == nil
end

function Rules.declaredFunctionName(code: string): string?
	return string.match(code, "^%s*local%s+function%s+([%w_]+)")
		or string.match(code, "^%s*function%s+[%w_.:]-([%w_]+)%s*[<(]")
end

function Rules.isGenericLocalFunction(code: string): boolean
	return string.match(code, "^%s*local%s+function%s+[%w_]+%s*<") ~= nil
end

function Rules.startsTypeFunction(code: string): boolean
	return string.match(code, "^%s*export%s+type%s+function%s") ~= nil
		or string.match(code, "^%s*type%s+function%s") ~= nil
end

local function shippedProblems(code: string): { string }
	local messages = {}
	local luauOnly = Rules.luauOnlyCall(code)
	if luauOnly then
		table.insert(messages, luauOnly .. " does not exist in Lua 5.1 (WoW)")
	end
	if Rules.isGeneralizedIteration(code) then
		table.insert(messages, "generalized iteration: use pairs() or ipairs() (Lua 5.1 has no __iter)")
	end
	if Rules.isGenericLocalFunction(code) then
		table.insert(
			messages,
			"generic local function: luau-lsp 1.70.1 infers wrong types or crashes on these; use any-typed private helpers"
		)
	end
	if string.find(code, "`", 1, true) then
		table.insert(messages, "string interpolation: use .. or string.format")
	end
	return messages
end

function Rules.check(path: string, source: string): { Problem }
	local kind = Rules.fileKind(path)
	local lines = string.split(string.gsub(source, "\r", ""), "\n")
	local problems: { Problem } = {}
	local function report(line: number, message: string)
		table.insert(problems, { line = line, message = message })
	end

	if lines[1] ~= "--!strict" then
		report(1, "must start with --!strict")
	end

	local enclosingFunction: string? = nil
	local insideTypeFunction = false
	for number, line in lines do
		local code = Rules.codeOf(line)
		if Rules.weakensChecking(line) then
			report(number, "weakens the type checker")
		end
		if string.match(line, "^%s*%-%-%[=*%[") then
			report(number, "block comment: name things instead")
		elseif not Rules.isAllowedComment(line, kind) then
			report(number, "comment: use a descriptive name, a smaller function or a test instead")
		end
		enclosingFunction = Rules.declaredFunctionName(code) or enclosingFunction
		if string.find(code, ":: any", 1, true) then
			local name = enclosingFunction or ""
			if string.sub(name, 1, #"unchecked") ~= "unchecked" then
				report(number, "`:: any` outside a function named unchecked...")
			end
		end
		if Rules.startsTypeFunction(code) then
			insideTypeFunction = true
		elseif insideTypeFunction and line == "end" then
			insideTypeFunction = false
		elseif kind == "shipped" and not insideTypeFunction then
			for _, message in shippedProblems(code) do
				report(number, message)
			end
		end
	end
	return problems
end

return Rules
