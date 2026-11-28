--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local Diagnostics = require("./fixtures/diagnostics")

type Diagnostic = Diagnostics.Diagnostic

local updateExpectations = table.find(process.args, "--update") ~= nil

local function luauFilesIn(directory: string): { string }
	local files = {}
	for _, entry in fs.readDir(directory) do
		if string.match(entry, "%.luau$") then
			table.insert(files, directory .. "/" .. entry)
		end
	end
	table.sort(files)
	return files
end

local function analyze(file: string): { Diagnostic }
	local result = process.exec(
		"luau-lsp",
		{ "analyze", "--platform=standard", "--flag:LuauSolverV2=true", "--base-luaurc=.luaurc", file }
	)
	local output = result.stdout .. "\n" .. result.stderr
	if not result.ok and result.code ~= 1 then
		print(output)
		error(file .. ": luau-lsp exited with code " .. result.code, 0)
	end
	return Diagnostics.parse(output)
end

local function readExpected(path: string): string?
	if not fs.isFile(path) then
		return nil
	end
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local failures = 0
local function fail(message: string)
	failures += 1
	print("FAIL " .. message)
end

local function checkPassingFixture(file: string)
	local diagnostics = analyze(file)
	for _, diagnostic in diagnostics do
		fail(
			string.format(
				"%s:%d:%d: unexpected diagnostic: %s",
				diagnostic.file,
				diagnostic.line,
				diagnostic.column,
				diagnostic.text
			)
		)
	end
	print(string.format("%s %s", if #diagnostics == 0 then "ok  " else "FAIL", file))
end

local function checkFailingFixture(file: string)
	local failuresBefore = failures
	local diagnostics = analyze(file)
	for _, diagnostic in diagnostics do
		if diagnostic.file ~= file then
			fail(string.format("%s: a diagnostic in the library: %s:%d", file, diagnostic.file, diagnostic.line))
		end
	end

	local actual = Diagnostics.render(diagnostics)
	local expectedPath = string.gsub(file, "%.luau$", ".expected")
	if updateExpectations then
		fs.writeFile(expectedPath, actual)
	elseif readExpected(expectedPath) ~= actual then
		fail(file .. ": diagnostics differ from " .. expectedPath .. ". Actual:\n" .. actual)
	end

	local markers = Diagnostics.markers(fs.readFile(file))
	for _, marker in Diagnostics.unmatchedMarkers(markers, diagnostics) do
		fail(string.format("%s:%d: expected an error containing %q", file, marker.line, marker.phrase))
	end
	for _, line in Diagnostics.unmarkedLines(markers, diagnostics) do
		fail(string.format("%s:%d: a diagnostic on a line not marked expect-error", file, line))
	end

	print(
		string.format(
			"%s %s (%d diagnostics, %d marked lines)",
			if failures == failuresBefore then "ok  " else "FAIL",
			file,
			#diagnostics,
			#markers
		)
	)
end

for _, file in luauFilesIn("tests/pass") do
	checkPassingFixture(file)
end
for _, file in luauFilesIn("tests/fail") do
	checkFailingFixture(file)
end

if failures > 0 then
	print(failures .. " failure(s)")
	process.exit(1)
end
