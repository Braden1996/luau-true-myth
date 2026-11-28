--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local TrueMyth = require("../../../libraries/luau/pure/true-myth/src/TrueMyth")

local OUTPUT = ".github/banner.svg"
local MODULES = { "Delay", "Exhaustive", "Maybe", "Result", "Task", "Toolbelt" }

type Attributes = { [string]: string | number }

local function attrs(t: Attributes): string
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		table.insert(parts, string.format('%s="%s"', key, tostring(t[key])))
	end
	return table.concat(parts, " ")
end

local function el(name: string, a: Attributes, body: string?): string
	if body then
		return "<" .. name .. " " .. attrs(a) .. ">" .. body .. "</" .. name .. ">"
	end
	return "<" .. name .. " " .. attrs(a) .. "/>"
end

local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function gradient(id: string, from: string, to: string): string
	return string.format(
		'    <linearGradient id="%s" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/>'
			.. '<stop offset="1" stop-color="%s"/></linearGradient>',
		id,
		from,
		to
	)
end

local MONO = "'JetBrains Mono','Cascadia Code',Consolas,monospace"
local SANS = "'Segoe UI','Inter','Helvetica Neue',Arial,sans-serif"

local function uncheckedModuleOf(name: string): { [string]: any }
	return (TrueMyth :: any)[name]
end

local function svg(): string
	local functions = 0
	for _, name in MODULES do
		for _, value in uncheckedModuleOf(name) do
			if type(value) == "function" then
				functions += 1
			end
		end
	end

	local lines = {
		'<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="400" viewBox="0 0 1280 400" role="img" aria-labelledby="title desc">',
		'  <title id="title">luau-true-myth</title>',
		'  <desc id="desc">Maybe, Result and Task for strict Luau, in Lune and in World of Warcraft addons</desc>',
		"  <defs>",
		gradient("bg", "#0d1117", "#1b1033"),
		gradient("ok", "#7ee2a8", "#2fb36d"),
		gradient("err", "#ff9a8b", "#e5484d"),
		gradient("core", "#8ab4ff", "#3d63dd"),
		'    <pattern id="dots" width="24" height="24" patternUnits="userSpaceOnUse">',
		"      " .. el("circle", { cx = 2, cy = 2, r = 1, fill = "#ffffff", ["fill-opacity"] = 0.05 }),
		"    </pattern>",
		"  </defs>",
		"  " .. el("rect", { width = 1280, height = 400, fill = "url(#bg)" }),
		"  " .. el("rect", { width = 1280, height = 400, fill = "url(#dots)" }),
	}

	local emblem = {
		el("path", {
			d = "M120 200 C 200 200, 220 110, 300 110",
			fill = "none",
			stroke = "url(#ok)",
			["stroke-width"] = 10,
			["stroke-linecap"] = "round",
		}),
		el("path", {
			d = "M120 200 C 200 200, 220 290, 300 290",
			fill = "none",
			stroke = "url(#err)",
			["stroke-width"] = 10,
			["stroke-linecap"] = "round",
		}),
		el("circle", { cx = 110, cy = 200, r = 34, fill = "url(#core)" }),
		el("text", {
			x = 110,
			y = 210,
			["font-family"] = MONO,
			["font-size"] = 26,
			["font-weight"] = 700,
			fill = "#0d1117",
			["text-anchor"] = "middle",
		}, "T?"),
		el("rect", { x = 300, y = 86, width = 70, height = 48, rx = 12, fill = "url(#ok)" }),
		el("text", {
			x = 335,
			y = 118,
			["font-family"] = MONO,
			["font-size"] = 22,
			["font-weight"] = 700,
			fill = "#0d1117",
			["text-anchor"] = "middle",
		}, "Ok"),
		el("rect", { x = 300, y = 266, width = 70, height = 48, rx = 12, fill = "url(#err)" }),
		el("text", {
			x = 335,
			y = 298,
			["font-family"] = MONO,
			["font-size"] = 22,
			["font-weight"] = 700,
			fill = "#0d1117",
			["text-anchor"] = "middle",
		}, "Err"),
	}
	for _, part in emblem do
		table.insert(lines, "  " .. part)
	end

	table.insert(lines, "  " .. el("text", {
		x = 440,
		y = 150,
		["font-family"] = SANS,
		["font-size"] = 68,
		["font-weight"] = 700,
		fill = "#ffffff",
		["letter-spacing"] = -1,
	}, "luau-true-myth"))
	table.insert(
		lines,
		"  "
			.. el(
				"text",
				{ x = 442, y = 196, ["font-family"] = SANS, ["font-size"] = 24, fill = "#c9d1ff" },
				"Maybe, Result and Task for strict Luau: Lune scripts and WoW addons alike"
			)
	)

	local tokens = {
		{ "local", "#c678dd" },
		{ " quest", "#e6edf3" },
		{ ": ", "#8b949e" },
		{ "Result", "#8ab4ff" },
		{ "<", "#8b949e" },
		{ "Quest", "#8ab4ff" },
		{ ", ", "#8b949e" },
		{ "NotFound", "#ff9a8b" },
		{ ">", "#8b949e" },
		{ " = ", "#8b949e" },
		{ "find", "#7ee2a8" },
		{ "(id)", "#e6edf3" },
	}
	local spans = {}
	for _, token in tokens do
		table.insert(spans, el("tspan", { fill = token[2] }, escape(token[1])))
	end
	table.insert(lines, "  " .. el("rect", {
		x = 440,
		y = 226,
		width = 640,
		height = 58,
		rx = 10,
		fill = "#0d1117",
		["fill-opacity"] = 0.8,
		stroke = "#3d63dd",
		["stroke-opacity"] = 0.6,
	}))
	table.insert(
		lines,
		"  " .. el("text", { x = 464, y = 263, ["font-family"] = MONO, ["font-size"] = 22 }, table.concat(spans))
	)

	local stats = string.format(
		"v%s  ·  %d functions  ·  --!strict on the new solver  ·  ships as Lua 5.1",
		TrueMyth.version,
		functions
	)
	table.insert(
		lines,
		"  " .. el("text", { x = 442, y = 336, ["font-family"] = SANS, ["font-size"] = 20, fill = "#7ee2a8" }, stats)
	)
	table.insert(lines, "</svg>")
	return table.concat(lines, "\n") .. "\n"
end

local content = svg()
if table.find(process.args, "--check") then
	local committed = if fs.isFile(OUTPUT) then string.gsub(fs.readFile(OUTPUT), "\r\n", "\n") else ""
	if committed ~= content then
		print("FAIL " .. OUTPUT .. " is stale: run `lune run scripts/banner` and commit it")
		process.exit(1)
	end
	print("ok   " .. OUTPUT .. " is up to date")
else
	fs.writeFile(OUTPUT, content)
	print("ok   wrote " .. OUTPUT)
end
