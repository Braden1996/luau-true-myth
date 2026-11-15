--!strict
-- Repository rules no off-the-shelf tool checks (see docs/strict-luau-guide.md):
--   every .luau file     starts with `--!strict`; no `--!nonstrict` or `--!nocheck`;
--                        every `:: any` cast has a `SAFETY:` comment on its line or within the 3 lines above;
--   src/ and wow/ only   (they ship to Lua 5.1 through darklua)
--                        no Luau-only library functions (table.clone, string.split, ...);
--                        no generalized iteration (`for k, v in t do`): use pairs/ipairs, which Lua 5.1 has;
--                        no string interpolation: darklua rewrites it, but the output is slow and unreadable.
-- Run with `lune run scripts/lint`.

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS = { "src", "wow", "scripts", "tests" }
local SHIPPED = { src = true, wow = true }

-- Library functions Luau adds over Lua 5.1 (WoW): calling one compiles but fails in the game.
local LUAU_ONLY = {
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

local function walk(dir: string, out: { string })
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, entry in entries do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(entry, "%.luau$") then
			table.insert(out, path)
		end
	end
end

local failures = 0
local function fail(file: string, line: number, message: string)
	failures += 1
	print(string.format("FAIL %s:%d: %s", file, line, message))
end

-- The code part of a line: drops a trailing `--` comment and the contents of simple string literals.
local function code(line: string): string
	local stripped = string.gsub(line, '"[^"]*"', '""')
	stripped = string.gsub(stripped, "'[^']*'", "''")
	local comment = string.find(stripped, "--", 1, true)
	return if comment then string.sub(stripped, 1, comment - 1) else stripped
end

local files = {}
for _, root in ROOTS do
	walk(root, files)
end

for _, file in files do
	local shipped = SHIPPED[string.match(file, "^([^/]+)") or ""] == true
	local lines = string.split(string.gsub(fs.readFile(file), "\r", ""), "\n")
	if lines[1] ~= "--!strict" then
		fail(file, 1, "must start with --!strict")
	end
	local inTypeFunction = false
	local inBlockComment = false
	for number, raw in lines do
		-- Block comments (`--[[ ... ]]`) are prose: blank them out.
		local line = raw
		if inBlockComment then
			if string.find(raw, "]]", 1, true) then
				inBlockComment = false
			end
			line = ""
		elseif string.match(raw, "^%s*%-%-%[=*%[") then
			inBlockComment = not string.find(raw, "]]", 1, true)
			line = ""
		end
		if string.match(line, "^%-%-!non?strict") or string.match(line, "^%-%-!nocheck") then
			fail(file, number, "weakens the type checker")
		end
		if string.find(code(line), ":: any", 1, true) then
			local justified = false
			for back = 0, 3 do
				if string.find(lines[number - back] or "", "SAFETY", 1, true) then
					justified = true
				end
			end
			if not justified then
				fail(file, number, "`:: any` without a SAFETY: comment explaining why it holds")
			end
		end
		-- Type function bodies run in the type checker, not the game, so the runtime rules skip them.
		if string.match(line, "^%s*export type function") or string.match(line, "^%s*type function") then
			inTypeFunction = true
		elseif inTypeFunction and line == "end" then
			inTypeFunction = false
		elseif shipped and not inTypeFunction then
			local body = code(line)
			for _, name in LUAU_ONLY do
				if string.find(body, name, 1, true) then
					fail(file, number, name .. " does not exist in Lua 5.1 (WoW)")
				end
			end
			if string.match(body, "^%s*for%s.-%sin%s") and not string.match(body, "%sin%s+[%w_.:]+%(") then
				fail(file, number, "generalized iteration: use pairs() or ipairs() (Lua 5.1 has no __iter)")
			end
			if string.find(body, "`", 1, true) then
				fail(file, number, "string interpolation: use .. or string.format")
			end
		end
	end
end

print(string.format("%s lint: %d files, %d problems", if failures == 0 then "ok  " else "FAIL", #files, failures))
if failures > 0 then
	process.exit(1)
end
