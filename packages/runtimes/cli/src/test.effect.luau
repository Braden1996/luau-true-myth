--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Harness = require("../../../libraries/luau/pure/test-harness/src/Harness")
local Source = require("../../../libraries/luau/pure/true-myth/src/TrueMyth")

type Lib = typeof(Source)
type SpecModule = Harness.SpecModule<Lib>

local function uncheckedLibraryTable(library: unknown): { [string]: any }
	return library :: any
end

local function uncheckedModuleOf(lib: Lib, name: string): { [string]: any }
	return (lib :: any)[name]
end

local function uncheckedAsLib(wrapped: { [string]: any }): Lib
	return wrapped :: any
end

local function uncheckedRequireSpec(path: string): SpecModule
	return (require :: any)(path)
end

local BUNDLE = "dist/TrueMyth.lua"

local lua51 = process.exec("luajit", {
	"-e",
	"local ns = {}; assert(assert(loadfile('dist/TrueMyth.lua'))('MyAddon', ns) == ns.TrueMyth); assert(ns.TrueMyth.Maybe.just(1).value == 1)",
}, { stdio = "inherit" })
if not lua51.ok then
	error("LuaJIT failed to load the committed bundle", 0)
end
local MODULES = { "Delay", "Exhaustive", "Maybe", "Result", "Task", "Toolbelt" }

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
	coroutine = {
		source = uncheckedLibraryTable(coroutine),
		names = { "create", "resume", "running", "status", "wrap", "yield" },
	},
	math = {
		source = uncheckedLibraryTable(math),
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
		source = uncheckedLibraryTable(string),
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
	table = { source = uncheckedLibraryTable(table), names = { "concat", "insert", "remove", "sort" } },
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

local function loadBundle(): (Lib, { [string]: any })
	if not fs.isFile(BUNDLE) then
		error(BUNDLE .. " is missing: run `sgt run bundle` first", 0)
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

local function instrument(lib: Lib, used: { [string]: true }): Lib
	local wrapped: { [string]: any } = { version = lib.version }
	for _, name in MODULES do
		local module = uncheckedModuleOf(lib, name)
		wrapped[name] = setmetatable({}, {
			__index = function(_, key: string): any
				used[name .. "." .. key] = true
				return module[key]
			end,
		})
	end
	return uncheckedAsLib(wrapped)
end

local specFiles = {}
for _, entry in fs.readDir("packages/libraries/luau/pure/true-myth/src") do
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
		local spec =
			uncheckedRequireSpec("../../../libraries/luau/pure/true-myth/src/" .. string.gsub(file, "%.luau$", ""))
		spec.suite(instrument(build.lib, used), Harness.context(report, build.name .. " " .. file))
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

local missing = {}
for _, name in MODULES do
	for key, value in uncheckedModuleOf(Source, name) do
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
