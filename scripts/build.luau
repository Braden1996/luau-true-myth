--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local Source = require("../packages/true-myth/src/TrueMyth")

local OUTPUT = "dist/TrueMyth.lua"
local SCRATCH = ".build"
local check = table.find(process.args, "--check") ~= nil

local function run(program: string, args: { string }, stdin: string?): string
	local result = process.exec(program, args, { stdin = stdin })
	if not result.ok then
		print(result.stdout .. result.stderr)
		error(program .. " " .. table.concat(args, " ") .. " failed", 0)
	end
	return result.stdout
end

local function header(): string
	local licence = string.gsub(fs.readFile("LICENSE"), "\r\n", "\n")
	local lines = {
		"-- luau-true-myth " .. Source.version .. ": Maybe, Result and Task for Lua 5.1 (World of Warcraft addons).",
		"-- https://github.com/Braden1996/luau-true-myth - generated from the Luau sources by darklua; do not edit.",
		"-- Listed in a .toc it stores the library as `ns.TrueMyth`; loaded any other way it returns it.",
		"--",
	}
	for line in string.gmatch(licence, "([^\n]*)\n") do
		table.insert(lines, if line == "" then "--" else "-- " .. line)
	end
	return table.concat(lines, "\n") .. "\n\n"
end

if not fs.isDir(SCRATCH) then
	fs.writeDir(SCRATCH)
end
local raw = SCRATCH .. "/TrueMyth.raw.lua"
run("darklua", { "process", "--config", ".darklua.json", "wow/TrueMyth.luau", raw })
local bundle = header() .. string.gsub(fs.readFile(raw), "\r\n", "\n")
local built = SCRATCH .. "/TrueMyth.lua"
fs.writeFile(built, bundle)

run("stylua", { "--syntax", "Lua51", "--check", "-" }, bundle)
run("selene", { "--config", "selene-lua51.toml", "--display-style", "quiet", built })

if check then
	local committed = if fs.isFile(OUTPUT) then string.gsub(fs.readFile(OUTPUT), "\r\n", "\n") else ""
	if committed ~= bundle then
		print("FAIL " .. OUTPUT .. " is stale: run `moon run lib:build` and commit the result")
		process.exit(1)
	end
	print("ok   " .. OUTPUT .. " is up to date, valid Lua 5.1, and uses only Lua 5.1 globals")
else
	if not fs.isDir("dist") then
		fs.writeDir("dist")
	end
	fs.writeFile(OUTPUT, bundle)
	print("ok   wrote " .. OUTPUT .. " (valid Lua 5.1, only Lua 5.1 globals)")
end
