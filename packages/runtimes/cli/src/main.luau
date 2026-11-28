--!strict

local process = require("@lune/process")

local command = process.args[1]
local tasks: { [string]: string } = {
	banner = "banner.effect",
	bundle = "build.effect",
	fixtures = "fixtures.effect",
	lint = "lint.effect",
	test = "test.effect",
}

local task = if command then tasks[command] else nil
if task == nil then
	print("Usage: lune run packages/runtimes/cli/src/main <banner|bundle|fixtures|lint|test>")
	process.exit(1)
	return
end

local args = { "run", "packages/runtimes/cli/src/" .. task }
for index = 2, #process.args do
	table.insert(args, process.args[index])
end
local result = process.exec("lune", args, { stdio = "inherit" })
process.exit(result.code)
