--!strict

local Harness = {}

export type T = {
	test: (name: string, body: () -> ()) -> (),
	equal: (actual: unknown, expected: unknown, label: string?) -> (),
	same: (actual: unknown, expected: unknown, label: string?) -> (),
	raises: (f: () -> (), fragment: string) -> (),
}

export type TestCase = {
	name: string,
	run: () -> (),
}

export type SpecModule<Lib> = {
	tests: { TestCase },
	suite: (lib: Lib, t: T) -> (),
}

export type Report = { passed: number, failed: { string } }

export type FakeClock = {
	schedule: (seconds: number, callback: () -> ()) -> (),
	advance: (seconds: number) -> (),
	now: () -> number,
	pending: () -> number,
}

local function uncheckedFields(value: unknown): { [any]: any }
	return value :: any
end

local function render(value: unknown, depth: number?): string
	local level = depth or 0
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" or level > 3 then
		return tostring(value)
	end
	local keys = {}
	for key in pairs(uncheckedFields(value)) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: any, b: any): boolean
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, tostring(key) .. " = " .. render(uncheckedFields(value)[key], level + 1))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deepEqual(a: unknown, b: unknown): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	local ta, tb = uncheckedFields(a), uncheckedFields(b)
	for key, value in pairs(ta) do
		if not deepEqual(value, tb[key]) then
			return false
		end
	end
	for key in pairs(tb) do
		if ta[key] == nil then
			return false
		end
	end
	return true
end

local function fail(label: string?, message: string)
	error((if label then label .. ": " else "") .. message, 0)
end

local function assertEqual(actual: unknown, expected: unknown, label: string?)
	if not deepEqual(actual, expected) then
		fail(label, "expected " .. render(expected) .. ", got " .. render(actual))
	end
end

local function assertSame(actual: unknown, expected: unknown, label: string?)
	if not rawequal(actual, expected) then
		fail(label, "expected the same value as " .. render(expected) .. ", got " .. render(actual))
	end
end

local function assertRaises(f: () -> (), fragment: string)
	local ok, raised = pcall(f)
	if ok then
		fail(nil, "expected an error containing " .. string.format("%q", fragment))
	elseif not string.find(tostring(raised), fragment, 1, true) then
		fail(nil, "expected an error containing " .. string.format("%q", fragment) .. ", got " .. tostring(raised))
	end
end

function Harness.context(report: Report, prefix: string): T
	return {
		test = function(name: string, body: () -> ())
			local ok, raised = pcall(body)
			if ok then
				report.passed += 1
			else
				table.insert(report.failed, prefix .. " > " .. name .. ": " .. tostring(raised))
			end
		end,
		equal = assertEqual,
		same = assertSame,
		raises = assertRaises,
	}
end

function Harness.spec<Lib>(source: Lib, suite: (lib: Lib, t: T) -> ()): SpecModule<Lib>
	local cases: { TestCase } = {}
	local collector: T = {
		test = function(name: string, body: () -> ())
			table.insert(cases, { name = name, run = body })
		end,
		equal = assertEqual,
		same = assertSame,
		raises = assertRaises,
	}
	suite(source, collector)
	return {
		tests = cases,
		suite = suite,
	}
end

function Harness.fakeClock(): FakeClock
	type Entry = { at: number, order: number, callback: () -> () }
	local now = 0
	local order = 0
	local queue: { Entry } = {}
	return {
		schedule = function(seconds: number, callback: () -> ())
			order += 1
			table.insert(queue, { at = now + seconds, order = order, callback = callback })
		end,
		advance = function(seconds: number)
			local target = now + seconds
			while true do
				local nextIndex: number? = nil
				for index, entry in ipairs(queue) do
					if entry.at <= target then
						local best = if nextIndex then queue[nextIndex] else nil
						if best == nil or entry.at < best.at or (entry.at == best.at and entry.order < best.order) then
							nextIndex = index
						end
					end
				end
				if nextIndex == nil then
					break
				end
				local entry = table.remove(queue, nextIndex) :: Entry
				now = entry.at
				entry.callback()
			end
			now = target
		end,
		now = function(): number
			return now
		end,
		pending = function(): number
			return #queue
		end,
	}
end

return Harness
