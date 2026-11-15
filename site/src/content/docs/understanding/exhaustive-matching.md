---
title: Exhaustive matching
description: Make the type checker fail when a variant of a tagged union is not handled.
---

Luau does not check that an `if`/`elseif` chain over a union's `kind` covers every variant. It does not report a
comparison with a tag the union does not have: `e.kind == "Expired"` type-checks. End every chain with `Exhaustive.casesHandled`:

```luau
local function describe(e: LookupError): string
	if e.kind == "NotFound" then
		return "no quest " .. e.id
	elseif e.kind == "Invalid" then
		return e.reason
	end
	return TrueMyth.Exhaustive.casesHandled(e)
end
```

When every variant is handled, `e` has been narrowed to `never` by the last line, and the call type-checks. Add a
`Timeout` variant to `LookupError` and forget it here, and luau-lsp reports:

```text
TypeError: Expected this to be unreachable, but got 'Timeout'
```

If the call is ever reached at run time, for example with data from outside the type system, it raises. That is
a defect, not an expected failure.

`Maybe.match`, `Result.match` and `Task.match` are exhaustive by construction: their matcher tables need a
handler for every variant.
