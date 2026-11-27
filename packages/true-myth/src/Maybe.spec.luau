--!strict
local Harness = require("@luau-true-myth/test-harness/Harness")
local Types = require("./TrueMyth")

type Lib = typeof(Types)
type Maybe<T> = Types.Maybe<T>

return Harness.spec(Types, function(lib: Lib, t: Harness.T)
	local Maybe = lib.Maybe

	t.test("just, nothing and of build tagged tables", function()
		t.equal(Maybe.just(1), { kind = "Just", value = 1 })
		t.equal(Maybe.nothing(), { kind = "Nothing" })
		t.same(Maybe.nothing(), Maybe.nothing(), "Nothing is shared")
		t.equal(Maybe.of(2), { kind = "Just", value = 2 })
		t.equal(Maybe.of(nil), { kind = "Nothing" })
		t.equal(Maybe.of(false), { kind = "Just", value = false }, "false is a value")
	end)

	t.test("just(nil) is a defect", function()
		t.raises(function()
			Maybe.just(nil)
		end, "Maybe.just: value is nil")
	end)

	t.test("isJust and isNothing", function()
		t.equal(Maybe.isJust(Maybe.just(1)), true)
		t.equal(Maybe.isJust(Maybe.nothing()), false)
		t.equal(Maybe.isNothing(Maybe.nothing()), true)
		t.equal(Maybe.isNothing(Maybe.just(1)), false)
	end)

	t.test("map applies to Just and turns a nil result into Nothing", function()
		t.equal(
			Maybe.map(Maybe.just(2), function(n: number): number
				return n * 3
			end),
			Maybe.just(6)
		)
		t.equal(
			Maybe.map(Maybe.just(2), function(_: number): string?
				return nil
			end),
			Maybe.nothing()
		)
		local m: Maybe<number> = Maybe.nothing()
		t.equal(Maybe.map(m, tostring), Maybe.nothing())
	end)

	t.test("mapOr and mapOrElse", function()
		local function double(n: number): number
			return n * 2
		end
		local none: Maybe<number> = Maybe.nothing()
		t.equal(Maybe.mapOr(Maybe.just(2), 0, double), 4)
		t.equal(Maybe.mapOr(none, 0, double), 0)
		t.equal(
			Maybe.mapOrElse(Maybe.just(2), function(): number
				return -1
			end, double),
			4
		)
		t.equal(
			Maybe.mapOrElse(none, function(): number
				return -1
			end, double),
			-1
		)
	end)

	t.test("match calls exactly one handler", function()
		local matcher = {
			Just = function(n: number): string
				return "just " .. n
			end,
			Nothing = function(): string
				return "nothing"
			end,
		}
		local none: Maybe<number> = Maybe.nothing()
		t.equal(Maybe.match(Maybe.just(1), matcher), "just 1")
		t.equal(Maybe.match(none, matcher), "nothing")
	end)

	t.test("andThen chains optional steps", function()
		local function half(n: number): Maybe<number>
			return if n % 2 == 0 then Maybe.just(n / 2) else Maybe.nothing()
		end
		t.equal(Maybe.andThen(Maybe.just(8), half), Maybe.just(4))
		t.equal(Maybe.andThen(Maybe.just(3), half), Maybe.nothing())
		t.equal(Maybe.andThen(Maybe.nothing(), half), Maybe.nothing())
	end)

	t.test("and_, or_ and orElse", function()
		local none: Maybe<number> = Maybe.nothing()
		t.equal(Maybe.and_(Maybe.just(1), Maybe.just("b")), Maybe.just("b"))
		t.equal(Maybe.and_(none, Maybe.just("b")), Maybe.nothing())
		t.equal(Maybe.or_(Maybe.just(1), Maybe.just(2)), Maybe.just(1))
		t.equal(Maybe.or_(none, Maybe.just(2)), Maybe.just(2))
		local calls = 0
		local function fallback(): Maybe<number>
			calls += 1
			return Maybe.just(9)
		end
		t.equal(Maybe.orElse(Maybe.just(1), fallback), Maybe.just(1))
		t.equal(calls, 0, "orElse is lazy")
		t.equal(Maybe.orElse(none, fallback), Maybe.just(9))
		t.equal(calls, 1)
	end)

	t.test("unwrapOr and unwrapOrElse", function()
		local none: Maybe<number> = Maybe.nothing()
		t.equal(Maybe.unwrapOr(Maybe.just(1), 0), 1)
		t.equal(Maybe.unwrapOr(none, 0), 0)
		t.equal(
			Maybe.unwrapOrElse(Maybe.just(1), function(): number
				return 0
			end),
			1
		)
		t.equal(
			Maybe.unwrapOrElse(none, function(): number
				return 7
			end),
			7
		)
	end)

	t.test("flatten removes one level", function()
		t.equal(Maybe.flatten(Maybe.just(Maybe.just(1))), Maybe.just(1))
		local inner: Maybe<Maybe<number>> = Maybe.just(Maybe.nothing())
		t.equal(Maybe.flatten(inner), Maybe.nothing())
		local outer: Maybe<Maybe<number>> = Maybe.nothing()
		t.equal(Maybe.flatten(outer), Maybe.nothing())
	end)

	t.test("filter keeps matching values", function()
		local function positive(n: number): boolean
			return n > 0
		end
		t.equal(Maybe.filter(Maybe.just(1), positive), Maybe.just(1))
		t.equal(Maybe.filter(Maybe.just(-1), positive), Maybe.nothing())
		t.equal(Maybe.filter(Maybe.nothing(), positive), Maybe.nothing())
	end)

	t.test("equals compares variant and value", function()
		local none: Maybe<number> = Maybe.nothing()
		t.equal(Maybe.equals(Maybe.just(1), Maybe.just(1)), true)
		t.equal(Maybe.equals(Maybe.just(1), Maybe.just(2)), false)
		t.equal(Maybe.equals(Maybe.just(1), none), false)
		t.equal(Maybe.equals(none, Maybe.nothing()), true)
	end)

	t.test("toString renders nested values", function()
		t.equal(Maybe.toString(Maybe.just(1)), "Just(1)")
		t.equal(Maybe.toString(Maybe.just("a")), 'Just("a")')
		t.equal(Maybe.toString(Maybe.nothing()), "Nothing")
		t.equal(Maybe.toString(Maybe.just(Maybe.just(true))), "Just(Just(true))")
		t.equal(Maybe.toString(Maybe.just(lib.Result.err("e"))), 'Just(Err("e"))')
		t.equal(Maybe.toString(Maybe.just(lib.Result.ok(1))), "Just(Ok(1))")
	end)

	t.test("inspect runs only for Just and returns the input", function()
		local seen: { number } = {}
		local just = Maybe.just(5)
		t.same(
			Maybe.inspect(just, function(n: number)
				table.insert(seen, n)
			end),
			just
		)
		local none: Maybe<number> = Maybe.nothing()
		Maybe.inspect(none, function(n: number)
			table.insert(seen, n)
		end)
		t.equal(seen, { 5 })
	end)

	t.test("first, last and find", function()
		t.equal(Maybe.first({ 1, 2, 3 }), Maybe.just(1))
		t.equal(Maybe.first({}), Maybe.nothing())
		t.equal(Maybe.last({ 1, 2, 3 }), Maybe.just(3))
		t.equal(Maybe.last({}), Maybe.nothing())
		local function even(n: number): boolean
			return n % 2 == 0
		end
		t.equal(Maybe.find({ 1, 2, 4 }, even), Maybe.just(2))
		t.equal(Maybe.find({ 1, 3 }, even), Maybe.nothing())
	end)

	t.test("get reads a map entry", function()
		local ages: { [string]: number } = { ada = 36 }
		t.equal(Maybe.get(ages, "ada"), Maybe.just(36))
		t.equal(Maybe.get(ages, "bob"), Maybe.nothing())
	end)

	t.test("all and values", function()
		t.equal(Maybe.all({ Maybe.just(1), Maybe.just(2) }), Maybe.just({ 1, 2 }))
		t.equal(Maybe.all({ Maybe.just(1), Maybe.nothing() }), Maybe.nothing())
		t.equal(Maybe.all({} :: { Maybe<number> }), Maybe.just({}))
		t.equal(Maybe.values({ Maybe.just(1), Maybe.nothing(), Maybe.just(3) }), { 1, 3 })
	end)

	t.test("safe wraps a nilable function", function()
		local lookup = Maybe.safe(function(key: string): number?
			return if key == "a" then 1 else nil
		end)
		t.equal(lookup("a"), Maybe.just(1))
		t.equal(lookup("b"), Maybe.nothing())
	end)
end)
