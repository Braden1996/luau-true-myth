--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local Rules = require("./lint/rules")

local ROOTS = { "packages", "wow", "scripts", "tests" }

local function luauFilesUnder(directory: string, found: { string })
	local entries = fs.readDir(directory)
	table.sort(entries)
	for _, entry in entries do
		local path = directory .. "/" .. entry
		if fs.isDir(path) then
			luauFilesUnder(path, found)
		elseif string.match(entry, "%.luau$") then
			table.insert(found, path)
		end
	end
end

local files = {}
for _, root in ROOTS do
	luauFilesUnder(root, files)
end

local problemCount = 0
for _, file in files do
	local problems: { Rules.Problem } = Rules.check(file, fs.readFile(file))
	for _, problem in problems do
		problemCount += 1
		print(string.format("FAIL %s:%d: %s", file, problem.line, problem.message))
	end
end

print(
	string.format("%s lint: %d files, %d problems", if problemCount == 0 then "ok  " else "FAIL", #files, problemCount)
)
if problemCount > 0 then
	process.exit(1)
end
