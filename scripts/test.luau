--!strict
-- Runs every spec in tests/spec against two builds of the library:
--   luau    the Luau sources (src/TrueMyth), as Lune scripts use them;
--   lua51   the darklua bundle (dist/TrueMyth.lua, from `scripts/build`), loaded in an environment that has only
--           Lua 5.1's standard library, as WoW addons use it.
-- Then checks API coverage: every public function of every module must be called by some spec.
-- Run with `lune run scripts/test` (after `lune run scripts/build`).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Harness = require("../tests/harness")
local Source = require("../src/TrueMyth")

type Lib = typeof(Source)
type Spec = (lib: Lib, t: Harness.T) -> ()

local BUNDLE = "dist/TrueMyth.lua"
local MODULES = { "Delay", "Exhaustive", "Maybe", "Result", "Task", "Toolbelt" }

-- Lua 5.1's standard library as WoW has it (no io, os, loadfile, dofile or debug). Luau-only additions such as
-- table.clone, table.find, string.split or table.freeze are deliberately absent, so a bundle that uses them fails.
local LUA51_GLOBALS: { [string]: any } = {
	assert = assert,
	error = error,
	getmetatable = getmetatable,
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	pcall = pcall,
	print = print,
	rawequal = rawequal,
	rawget = rawget,
	rawset = rawset,
	select = select,
	setmetatable = setmetatable,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = table.unpack,
	xpcall = xpcall,
}
type Library = { source: { [string]: any }, names: { string } }
local LUA51_LIBRARIES: { [string]: Library } = {
	-- SAFETY: a standard library table read by the names below, which it has.
	coroutine = { source = coroutine :: any, names = { "create", "resume", "running", "status", "wrap", "yield" } },
	math = {
		-- SAFETY: a standard library table read by the names below, which it has.
		source = math :: any,
		names = {
			"abs",
			"acos",
			"asin",
			"atan",
			"atan2",
			"ceil",
			"cos",
			"cosh",
			"deg",
			"exp",
			"floor",
			"fmod",
			"frexp",
			"huge",
			"ldexp",
			"log",
			"log10",
			"max",
			"min",
			"modf",
			"pi",
			"pow",
			"rad",
			"random",
			"randomseed",
			"sin",
			"sinh",
			"sqrt",
			"tan",
			"tanh",
		},
	},
	string = {
		-- SAFETY: a standard library table read by the names below, which it has.
		source = string :: any,
		names = {
			"byte",
			"char",
			"find",
			"format",
			"gmatch",
			"gsub",
			"len",
			"lower",
			"match",
			"rep",
			"reverse",
			"sub",
			"upper",
		},
	},
	-- SAFETY: a standard library table read by the names below, which it has.
	table = { source = table :: any, names = { "concat", "insert", "remove", "sort" } },
}

local function lua51Environment(): { [string]: any }
	local env: { [string]: any } = table.clone(LUA51_GLOBALS)
	for library, spec in LUA51_LIBRARIES do
		local copy = {}
		for _, name in spec.names do
			copy[name] = spec.source[name]
		end
		env[library] = copy
	end
	env._G = env
	return env
end

-- Loads the Lua 5.1 bundle as WoW would: called with the addon name and namespace table.
local function loadBundle(): (Lib, { [string]: any })
	if not fs.isFile(BUNDLE) then
		error(BUNDLE .. " is missing: run `lune run scripts/build` first", 0)
	end
	local env = lua51Environment()
	local chunk = luau.load(fs.readFile(BUNDLE), { debugName = BUNDLE, environment = env, injectGlobals = false })
	local namespace: { [string]: any } = {}
	local returned = chunk("MyAddon", namespace)
	if namespace.TrueMyth ~= returned then
		error(BUNDLE .. ": the addon namespace did not receive the library", 0)
	end
	for key in env do
		if key ~= "_G" and LUA51_GLOBALS[key] == nil and LUA51_LIBRARIES[key] == nil then
			error(BUNDLE .. " created a global: " .. key, 0)
		end
	end
	return returned, namespace
end

-- Wraps each module so reads of its functions are recorded in `used`.
local function instrument(lib: Lib, used: { [string]: true }): Lib
	local wrapped: { [string]: any } = { version = lib.version }
	for _, name in MODULES do
		-- SAFETY: `name` is one of MODULES, each a key of `lib`; the module is read dynamically by name.
		local module = (lib :: any)[name]
		wrapped[name] = setmetatable({}, {
			__index = function(_, key: string): any
				used[name .. "." .. key] = true
				return module[key]
			end,
		})
	end
	-- SAFETY: same keys as `lib`, each module replaced by a read-through proxy.
	return wrapped :: any
end

local specFiles = {}
for _, entry in fs.readDir("tests/spec") do
	if string.match(entry, "%.spec%.luau$") then
		table.insert(specFiles, entry)
	end
end
table.sort(specFiles)

local used: { [string]: true } = {}
local failures: { string } = {}
local builds: { { name: string, lib: Lib } } = { { name = "luau", lib = Source } }
local ok, bundle = pcall(loadBundle)
if ok then
	table.insert(builds, { name = "lua51", lib = bundle })
else
	table.insert(failures, tostring(bundle))
end

for _, build in builds do
	local report: Harness.Report = { passed = 0, failed = {} }
	for _, file in specFiles do
		-- SAFETY: a dynamic path to a spec file, whose shape every spec declares (`return function(lib, t)`).
		local spec = (require :: any)("../tests/spec/" .. string.gsub(file, "%.luau$", "")) :: Spec
		spec(instrument(build.lib, used), Harness.context(report, build.name .. " " .. file))
	end
	for _, failure in report.failed do
		table.insert(failures, failure)
	end
	print(
		string.format(
			"%s %-6s %d passed, %d failed",
			if #report.failed == 0 then "ok  " else "FAIL",
			build.name,
			report.passed,
			#report.failed
		)
	)
end

if Source.version ~= (if ok then bundle.version else Source.version) then
	table.insert(failures, "the bundle's version differs from the sources'")
end

-- Coverage: every function each module exports must be read by some spec.
local missing = {}
for _, name in MODULES do
	-- SAFETY: `name` is one of MODULES, each a module table of the library.
	for key, value in (Source :: any)[name] do
		if type(value) == "function" and not used[name .. "." .. key] then
			table.insert(missing, name .. "." .. key)
		end
	end
end
table.sort(missing)
for _, name in missing do
	table.insert(failures, "no spec calls " .. tostring(name))
end
print(string.format("%s api coverage: %d untested functions", if #missing == 0 then "ok  " else "FAIL", #missing))

if #failures > 0 then
	for _, failure in failures do
		print("FAIL " .. failure)
	end
	process.exit(1)
end
