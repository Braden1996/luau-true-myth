--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local Source = require("../../../libraries/luau/pure/true-myth/src/TrueMyth")

local OUTPUT = "dist/TrueMyth.lua"
local GENERATED = ".sergeant/out/luau-true-myth/wow-bundle/main.lua"
local check = table.find(process.args, "--check") ~= nil

local function run(program: string, args: { string })
	local result = process.exec(program, args)
	if not result.ok then
		print(result.stdout .. result.stderr)
		error(program .. " " .. table.concat(args, " ") .. " failed", 0)
	end
end

local function header(): string
	local licence = string.gsub(fs.readFile("LICENSE"), "\r\n", "\n")
	local lines = {
		"-- luau-true-myth " .. Source.version .. ": Maybe, Result and Task for Lua 5.1 (World of Warcraft addons).",
		"-- https://github.com/Braden1996/luau-true-myth - generated from the Luau sources by Sergeant; do not edit.",
		"-- Listed in a .toc it stores the library as `ns.TrueMyth`; loaded any other way it returns it.",
		"--",
	}
	for line in string.gmatch(licence, "([^\n]*)\n") do
		table.insert(lines, if line == "" then "--" else "-- " .. line)
	end
	return table.concat(lines, "\n") .. "\n\n"
end

if not check then
	run("sgt", { "--no-daemon", "build", "@luau-true-myth/wow-bundle" })
end
local bundle = header() .. string.gsub(fs.readFile(GENERATED), "\r\n", "\n")

if check then
	local committed = if fs.isFile(OUTPUT) then string.gsub(fs.readFile(OUTPUT), "\r\n", "\n") else ""
	if committed ~= bundle then
		print("FAIL " .. OUTPUT .. " is stale: run `sgt run bundle` and commit the result")
		process.exit(1)
	end
	print("ok   " .. OUTPUT .. " is up to date")
else
	if not fs.isDir("dist") then
		fs.writeDir("dist")
	end
	fs.writeFile(OUTPUT, bundle)
	print("ok   wrote " .. OUTPUT)
end
