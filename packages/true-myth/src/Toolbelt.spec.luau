--!strict
local Harness = require("@luau-true-myth/test-harness/Harness")
local Types = require("./TrueMyth")

type Lib = typeof(Types)
type Maybe<T> = Types.Maybe<T>
type Result<T, E> = Types.Result<T, E>

return Harness.spec(Types, function(lib: Lib, t: Harness.T)
	local Maybe, Result, Toolbelt = lib.Maybe, lib.Result, lib.Toolbelt

	t.test("toMaybe drops the error", function()
		t.equal(Toolbelt.toMaybe(Result.ok(1)), Maybe.just(1))
		local failed: Result<number, string> = Result.err("e")
		t.equal(Toolbelt.toMaybe(failed), Maybe.nothing())
	end)

	t.test("toOkOrErr and toOkOrElseErr", function()
		local none: Maybe<number> = Maybe.nothing()
		t.equal(Toolbelt.toOkOrErr(Maybe.just(1), "missing"), Result.ok(1))
		t.equal(Toolbelt.toOkOrErr(none, "missing"), Result.err("missing"))
		local calls = 0
		local function missing(): string
			calls += 1
			return "missing"
		end
		t.equal(Toolbelt.toOkOrElseErr(Maybe.just(1), missing), Result.ok(1))
		t.equal(calls, 0, "the error is built only when needed")
		t.equal(Toolbelt.toOkOrElseErr(none, missing), Result.err("missing"))
	end)

	t.test("transposeResult", function()
		local justOk: Result<Maybe<number>, string> = Result.ok(Maybe.just(1))
		local okNothing: Result<Maybe<number>, string> = Result.ok(Maybe.nothing())
		local failed: Result<Maybe<number>, string> = Result.err("e")
		t.equal(Toolbelt.transposeResult(justOk), Maybe.just(Result.ok(1)))
		t.equal(Toolbelt.transposeResult(okNothing), Maybe.nothing())
		t.equal(Toolbelt.transposeResult(failed), Maybe.just(Result.err("e")))
	end)

	t.test("transposeMaybe", function()
		local justOk: Maybe<Result<number, string>> = Maybe.just(Result.ok(1))
		local justErr: Maybe<Result<number, string>> = Maybe.just(Result.err("e"))
		local none: Maybe<Result<number, string>> = Maybe.nothing()
		t.equal(Toolbelt.transposeMaybe(justOk), Result.ok(Maybe.just(1)))
		t.equal(Toolbelt.transposeMaybe(justErr), Result.err("e"))
		t.equal(Toolbelt.transposeMaybe(none), Result.ok(Maybe.nothing()))
	end)

	t.test("round trips", function()
		local values: { Result<Maybe<number>, string> } = {
			Result.ok(Maybe.just(1)),
			Result.ok(Maybe.nothing()),
			Result.err("e"),
		}
		for _, value in ipairs(values) do
			t.equal(Toolbelt.transposeMaybe(Toolbelt.transposeResult(value)), value)
		end
	end)
end)
