--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("../packages/test-harness/src/Harness")

type ToolingSpec = (t: Harness.T) -> ()

local function uncheckedRequireSpec(path: string): ToolingSpec
	return (require :: any)(path)
end

local function specFilesUnder(directory: string, found: { string })
	local entries = fs.readDir(directory)
	table.sort(entries)
	for _, entry in entries do
		local path = directory .. "/" .. entry
		if fs.isDir(path) then
			specFilesUnder(path, found)
		elseif string.match(entry, "%.spec%.luau$") then
			table.insert(found, path)
		end
	end
end

local specFiles = {}
specFilesUnder("scripts", specFiles)

local report: Harness.Report = { passed = 0, failed = {} }
for _, file in specFiles do
	local spec = uncheckedRequireSpec("../" .. string.gsub(file, "%.luau$", ""))
	spec(Harness.context(report, file))
end

for _, failure in report.failed do
	print("FAIL " .. failure)
end
print(
	string.format(
		"%s tooling specs: %d passed, %d failed (%d files)",
		if #report.failed == 0 then "ok  " else "FAIL",
		report.passed,
		#report.failed,
		#specFiles
	)
)
if #report.failed > 0 then
	process.exit(1)
end
