--!strict
-- A small test harness for the specs. Each spec is `return function(lib: Lib, t: Harness.T) ... end`, so the same
-- spec runs against the Luau sources and against the compiled Lua 5.1 bundle.

local Harness = {}

export type T = {
	--- Runs `body` as one test; an error raised in it (including a failed assertion) fails the test.
	test: (name: string, body: () -> ()) -> (),
	--- Deep equality: tables compare key by key, everything else with `==`.
	equal: (actual: unknown, expected: unknown, label: string?) -> (),
	--- Identity: `actual == expected` (rawequal for tables).
	same: (actual: unknown, expected: unknown, label: string?) -> (),
	--- `f()` must raise an error whose message contains `fragment`.
	raises: (f: () -> (), fragment: string) -> (),
}

export type Report = { passed: number, failed: { string } }

--- A manual clock implementing `Task.Schedule`: callbacks run when `advance` passes their time.
export type FakeClock = {
	schedule: (seconds: number, callback: () -> ()) -> (),
	advance: (seconds: number) -> (),
	now: () -> number,
	pending: () -> number,
}

local function render(value: unknown, depth: number?): string
	local level = depth or 0
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" or level > 3 then
		return tostring(value)
	end
	local keys = {}
	-- SAFETY: `value` is a table here (checked above); render only reads it.
	for key in pairs(value :: any) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: any, b: any): boolean
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in keys do
		-- SAFETY: as above, `value` is a table.
		table.insert(parts, tostring(key) .. " = " .. render((value :: any)[key], level + 1))
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
	-- SAFETY: both are tables here (checked above); deepEqual only reads them.
	local ta, tb = a :: any, b :: any
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

--- A fresh test context that records into `report` under `prefix`.
function Harness.context(report: Report, prefix: string): T
	local function fail(label: string?, message: string)
		error((if label then label .. ": " else "") .. message, 0)
	end
	return {
		test = function(name: string, body: () -> ())
			local ok, raised = pcall(body)
			if ok then
				report.passed += 1
			else
				table.insert(report.failed, prefix .. " > " .. name .. ": " .. tostring(raised))
			end
		end,
		equal = function(actual: unknown, expected: unknown, label: string?)
			if not deepEqual(actual, expected) then
				fail(label, "expected " .. render(expected) .. ", got " .. render(actual))
			end
		end,
		same = function(actual: unknown, expected: unknown, label: string?)
			if not rawequal(actual, expected) then
				fail(label, "expected the same value as " .. render(expected) .. ", got " .. render(actual))
			end
		end,
		raises = function(f: () -> (), fragment: string)
			local ok, raised = pcall(f)
			if ok then
				fail(nil, "expected an error containing " .. string.format("%q", fragment))
			elseif not string.find(tostring(raised), fragment, 1, true) then
				fail(
					nil,
					"expected an error containing " .. string.format("%q", fragment) .. ", got " .. tostring(raised)
				)
			end
		end,
	}
end

--- A manual clock for timer-based tasks.
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
				for index, entry in queue do
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
