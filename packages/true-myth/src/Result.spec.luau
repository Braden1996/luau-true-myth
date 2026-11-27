--!strict
local Harness = require("@luau-true-myth/test-harness/Harness")
local Types = require("./TrueMyth")

type Lib = typeof(Types)
type Result<T, E> = Types.Result<T, E>

return Harness.spec(Types, function(lib: Lib, t: Harness.T)
	local Result = lib.Result

	local function parse(text: string): Result<number, string>
		local n = tonumber(text)
		if n == nil then
			return Result.err("not a number: " .. text)
		end
		return Result.ok(n)
	end

	t.test("ok and err build tagged tables", function()
		t.equal(Result.ok(1), { kind = "Ok", value = 1 })
		t.equal(Result.err("e"), { kind = "Err", error = "e" })
		t.equal(Result.ok(nil), { kind = "Ok" }, "Ok may carry nil")
	end)

	t.test("isOk and isErr", function()
		t.equal(Result.isOk(parse("1")), true)
		t.equal(Result.isOk(parse("x")), false)
		t.equal(Result.isErr(parse("x")), true)
		t.equal(Result.isErr(parse("1")), false)
	end)

	t.test("map and mapErr touch one side", function()
		local function double(n: number): number
			return n * 2
		end
		t.equal(Result.map(parse("2"), double), Result.ok(4))
		t.equal(Result.map(parse("x"), double), Result.err("not a number: x"))
		t.equal(Result.mapErr(parse("x"), string.upper), Result.err("NOT A NUMBER: X"))
		t.equal(Result.mapErr(parse("2"), string.upper), Result.ok(2))
	end)

	t.test("mapOr and mapOrElse", function()
		t.equal(Result.mapOr(parse("2"), "none", tostring), "2")
		t.equal(Result.mapOr(parse("x"), "none", tostring), "none")
		local function length(e: string): string
			return tostring(#e)
		end
		t.equal(Result.mapOrElse(parse("2"), length, tostring), "2")
		t.equal(Result.mapOrElse(parse("x"), length, tostring), "15")
	end)

	t.test("match calls exactly one handler", function()
		local matcher = {
			Ok = function(n: number): string
				return "ok " .. n
			end,
			Err = function(e: string): string
				return "err " .. e
			end,
		}
		t.equal(Result.match(parse("1"), matcher), "ok 1")
		t.equal(Result.match(parse("x"), matcher), "err not a number: x")
	end)

	t.test("andThen chains fallible steps", function()
		local function positive(n: number): Result<number, string>
			return if n > 0 then Result.ok(n) else Result.err("not positive")
		end
		t.equal(Result.andThen(parse("3"), positive), Result.ok(3))
		t.equal(Result.andThen(parse("-3"), positive), Result.err("not positive"))
		t.equal(Result.andThen(parse("x"), positive), Result.err("not a number: x"))
	end)

	t.test("and_, or_ and orElse", function()
		t.equal(Result.and_(parse("1"), Result.ok("b")), Result.ok("b"))
		t.equal(Result.and_(parse("x"), Result.ok("b")), Result.err("not a number: x"))
		t.equal(Result.or_(parse("1"), Result.ok(9)), Result.ok(1))
		t.equal(Result.or_(parse("x"), Result.err(false)), Result.err(false))
		local function recover(e: string): Result<number, boolean>
			return if string.find(e, "x", 1, true) then Result.ok(0) else Result.err(true)
		end
		t.equal(Result.orElse(parse("1"), recover), Result.ok(1))
		t.equal(Result.orElse(parse("x"), recover), Result.ok(0))
		t.equal(Result.orElse(parse("y"), recover), Result.err(true))
	end)

	t.test("unwrapOr and unwrapOrElse", function()
		t.equal(Result.unwrapOr(parse("1"), 0), 1)
		t.equal(Result.unwrapOr(parse("x"), 0), 0)
		t.equal(
			Result.unwrapOrElse(parse("x"), function(e: string): number
				return #e
			end),
			15
		)
		t.equal(
			Result.unwrapOrElse(parse("4"), function(_: string): number
				return 0
			end),
			4
		)
	end)

	t.test("flatten removes one level", function()
		local nested: Result<Result<number, string>, string> = Result.ok(Result.ok(1))
		t.equal(Result.flatten(nested), Result.ok(1))
		local inner: Result<Result<number, string>, string> = Result.ok(Result.err("in"))
		t.equal(Result.flatten(inner), Result.err("in"))
		local outer: Result<Result<number, string>, string> = Result.err("out")
		t.equal(Result.flatten(outer), Result.err("out"))
	end)

	t.test("equals compares variant and payload", function()
		t.equal(Result.equals(parse("1"), parse("1")), true)
		t.equal(Result.equals(parse("1"), parse("2")), false)
		t.equal(Result.equals(parse("x"), parse("x")), true)
		t.equal(Result.equals(parse("1"), parse("x")), false)
	end)

	t.test("toString renders nested values", function()
		t.equal(Result.toString(parse("1")), "Ok(1)")
		t.equal(Result.toString(Result.err("e")), 'Err("e")')
		t.equal(Result.toString(Result.ok(lib.Maybe.nothing())), "Ok(Nothing)")
	end)

	t.test("inspect and inspectErr run for one side and return the input", function()
		local log: { string } = {}
		local good, bad = parse("1"), parse("x")
		t.same(
			Result.inspect(good, function(n: number)
				table.insert(log, "ok " .. n)
			end),
			good
		)
		Result.inspect(bad, function(n: number)
			table.insert(log, "ok " .. n)
		end)
		t.same(
			Result.inspectErr(bad, function(e: string)
				table.insert(log, "err " .. e)
			end),
			bad
		)
		Result.inspectErr(good, function(e: string)
			table.insert(log, "err " .. e)
		end)
		t.equal(log, { "ok 1", "err not a number: x" })
	end)

	t.test("all, any and partition", function()
		t.equal(Result.all({ parse("1"), parse("2") }), Result.ok({ 1, 2 }))
		t.equal(Result.all({ parse("1"), parse("x"), parse("y") }), Result.err("not a number: x"))
		t.equal(Result.all({} :: { Result<number, string> }), Result.ok({}))
		t.equal(Result.any({ parse("x"), parse("2") }), Result.ok(2))
		t.equal(Result.any({ parse("x"), parse("y") }), Result.err({ "not a number: x", "not a number: y" }))
		t.equal(Result.any({} :: { Result<number, string> }), Result.err({}))
		local values, errors = Result.partition({ parse("1"), parse("x"), parse("3") })
		t.equal(values, { 1, 3 })
		t.equal(errors, { "not a number: x" })
	end)

	t.test("tryOr and tryOrElse catch raised errors", function()
		t.equal(
			Result.tryOr("failed", function(): number
				return 1
			end),
			Result.ok(1)
		)
		t.equal(
			Result.tryOr("failed", function(): number
				error("boom")
			end),
			Result.err("failed")
		)
		local function describe(raised: unknown): string
			return if type(raised) == "table" then "table" else "other"
		end
		t.equal(
			Result.tryOrElse(describe, function(): number
				error({ code = 1 })
			end),
			Result.err("table")
		)
		t.equal(
			Result.tryOrElse(describe, function(): number
				return 2
			end),
			Result.ok(2)
		)
	end)

	t.test("safe wraps a raising function", function()
		local divide = Result.safe(function(a: number, b: number): number
			if b == 0 then
				error("division by zero", 0)
			end
			return a / b
		end, function(raised: unknown): string
			return tostring(raised)
		end)
		t.equal(divide(6, 3), Result.ok(2))
		t.equal(divide(1, 0), Result.err("division by zero"))
	end)
end)
