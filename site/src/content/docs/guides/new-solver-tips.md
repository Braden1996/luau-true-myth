---
title: Tips for the new solver
description: What luau-lsp's new type solver needs from code that uses the library.
---

Three things the new solver (luau-lsp 1.70.1) needs from your code.

## Annotate callback parameters that use operators

```luau
Result.map(r, function(n) return n + 1 end)          -- asks: "Consider placing the following annotations"
Result.map(r, function(n: number) return n + 1 end)  -- fine
```

Callbacks that only pass their parameter on, such as `tostring`, need no annotation.

## Give empty lists a type

An empty table literal has no element type, so the library cannot tell what it holds:

```luau
Result.all({})                                 -- error: expected a Result, got unknown
Result.all({} :: { Result<number, string> })   -- fine
```

## Name types that appear only in a result

`Task.withResolvers` has no arguments to infer its types from, so name them with a cast. The cast is checked:

```luau
local deferred = Task.withResolvers() :: Task.Deferred<number, string>
```

## Why the signatures look the way they do

Functions such as `Result.map` take the result's whole type `R` and read its payloads with `OkOf<R>` and
`ErrOf<R>`. On the new solver, the obvious signature `map<T, U, E>(r: Result<T, E>, f: (T) -> U)` rejects every
annotated callback. The [design notes](../../project/design/#whole-type-generics-with-type-functions) explain why,
and the [strict Luau guide](../../project/strict-luau-guide/#solver-findings) lists every solver finding.
