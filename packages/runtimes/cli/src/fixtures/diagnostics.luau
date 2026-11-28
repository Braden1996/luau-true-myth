--!strict

local Diagnostics = {}

export type Diagnostic = { file: string, line: number, column: number, text: string }

export type Marker = { line: number, phrase: string }

local DIAGNOSTIC_LINE = "^(.-)%((%d+),(%d+)%): (.*)$"
local MARKER = "%-%- expect%-error: (.-)%s*$"

local function isLogLine(line: string): boolean
	return string.match(line, "^%[") ~= nil
end

local function diagnosticFrom(line: string): Diagnostic?
	local path, lineNumber, column, text = string.match(line, DIAGNOSTIC_LINE)
	local parsedLine, parsedColumn = tonumber(lineNumber), tonumber(column)
	if path == nil or text == nil or parsedLine == nil or parsedColumn == nil then
		return nil
	end
	return { file = (string.gsub(path, "\\", "/")), line = parsedLine, column = parsedColumn, text = text }
end

local function inReadingOrder(a: Diagnostic, b: Diagnostic): boolean
	if a.file ~= b.file then
		return a.file < b.file
	elseif a.line ~= b.line then
		return a.line < b.line
	elseif a.column ~= b.column then
		return a.column < b.column
	end
	return a.text < b.text
end

function Diagnostics.parse(output: string): { Diagnostic }
	local diagnostics: { Diagnostic } = {}
	local current: Diagnostic? = nil
	for line in string.gmatch(string.gsub(output, "\r", ""), "[^\n]+") do
		local diagnostic = diagnosticFrom(line)
		if diagnostic then
			current = diagnostic
			table.insert(diagnostics, diagnostic)
		elseif current and not isLogLine(line) then
			current.text ..= "\n" .. line
		end
	end
	table.sort(diagnostics, inReadingOrder)
	return diagnostics
end

function Diagnostics.render(diagnostics: { Diagnostic }): string
	local lines = {}
	for _, diagnostic in diagnostics do
		table.insert(lines, string.format("%d:%d: %s", diagnostic.line, diagnostic.column, diagnostic.text))
	end
	return table.concat(lines, "\n") .. "\n"
end

function Diagnostics.markers(source: string): { Marker }
	local markers: { Marker } = {}
	for lineNumber, line in string.split(string.gsub(source, "\r", ""), "\n") do
		local phrase = string.match(line, MARKER)
		if phrase then
			table.insert(markers, { line = lineNumber, phrase = phrase })
		end
	end
	return markers
end

function Diagnostics.unmatchedMarkers(markers: { Marker }, diagnostics: { Diagnostic }): { Marker }
	local unmatched = {}
	for _, marker in markers do
		local matched = false
		for _, diagnostic in diagnostics do
			if diagnostic.line == marker.line and string.find(diagnostic.text, marker.phrase, 1, true) then
				matched = true
			end
		end
		if not matched then
			table.insert(unmatched, marker)
		end
	end
	return unmatched
end

function Diagnostics.unmarkedLines(markers: { Marker }, diagnostics: { Diagnostic }): { number }
	local markedLines: { [number]: true } = {}
	for _, marker in markers do
		markedLines[marker.line] = true
	end
	local seen: { [number]: true } = {}
	local unmarked = {}
	for _, diagnostic in diagnostics do
		if not markedLines[diagnostic.line] and not seen[diagnostic.line] then
			seen[diagnostic.line] = true
			table.insert(unmarked, diagnostic.line)
		end
	end
	return unmarked
end

return Diagnostics
