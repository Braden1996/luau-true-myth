---
title: Introduction
description: What luau-true-myth is, the everyday problems it solves in Luau, and how it differs from the TypeScript original.
---

If you just want to use it, jump to [Install](../getting-started/install/) or take the [Tour](../getting-started/tour/).

## What is it?

luau-true-myth gives Luau three small, well-tested types for the three things that most often go wrong in everyday
code:

- **Having nothing.** In Lua, "no value" is `nil`, and nothing stops you from using it as if it were a value. You
  find out at run time with "attempt to index nil", often far from the cause. **`Maybe`** makes "this might be
  missing" part of the value's type, so the type checker reminds you to handle it before you use it.
- **Things going wrong.** Lua reports failure in several inconsistent ways: `error()` and `pcall`, `nil, "message"`
  return pairs, or a `false` flag. None of them show up in a function's type, so callers forget to handle them.
  **`Result`** returns success or failure as a value, and the type says exactly which failures can happen.
- **Waiting for something.** In a game addon or a script, results often arrive later: after an event, a timer or a
  server reply. Callbacks make it easy to lose an error or forget a case. **`Task`** is a value that will become a
  success or a failure later, and it composes like `Result`.

None of these ideas are new. If you have used `Option` and `Result` in Rust, `Optional` in Swift, or `Maybe` in
Haskell, they will feel familiar. The library is a port of [true-myth](https://true-myth.dev), which brings the same
ideas to TypeScript.

## Why use a library for this?

You could write a `nil` check or a `pcall` wherever you need one, and most Lua code does. The trouble is that it
relies on everyone remembering, every time. A shared set of types turns those checks into something the type
checker enforces:

- **Fewer crashes from `nil`.** You cannot read the value out of a `Maybe` without first checking that it is
  there.
- **Errors you can see.** A function that returns `Result<Quest, NotFound>` tells every caller what can go wrong,
  and the checker makes sure they deal with it.
- **Validate once, at the edges.** Check input where it enters your code (a saved file, an event, a network reply)
  and turn it into a `Maybe` or `Result`. The code inside can then trust what it is given, instead of re-checking
  everywhere.
- **One well-tested vocabulary.** Every part of a codebase handles absence and failure the same way, with the same
  functions (`map`, `andThen`, `unwrapOr`, `match`), so the code is easier to read and review.

## How it differs from true-myth

The ideas and most of the function names come straight from true-myth. What is different is how they fit Luau and
the places Luau code runs:

- **Plain data you can save.** In TypeScript, true-myth's values are class instances. Here they are plain tables,
  such as `{ kind = "Ok", value = 42 }`. That matters in Lua: World of Warcraft's saved variables and JSON drop
  anything clever, and plain tables survive both unchanged.
- **Runs in a game and in scripts.** The same library works in [Lune](https://lune-org.github.io/docs) scripts and,
  compiled to plain Lua 5.1, inside World of Warcraft addons. Every test runs against both.
- **Async without promises.** Lua has no promises or event loop. `Task` is built on Lua's coroutines instead, and the
  game or script supplies the clock (`C_Timer.After` in WoW, `task.delay` in Lune).
- **Checks that Luau does not do on its own.** Luau will not warn you when an `if` chain forgets a case, so the
  library adds `Exhaustive.casesHandled`, which turns a forgotten case into a type error.
- **Shaped around Luau's type checker.** Some signatures look unusual because they are written to work well with
  Luau's newer type checker. You rarely need to think about this. The [details](../background/lua-vs-typescript/)
  are there if you are curious.

## Using these docs

- [Install](../getting-started/install/) and [Editor setup](../getting-started/editor-setup/) get you running.
- The [Tour](../getting-started/tour/) shows all three types in a few minutes.
- **Understanding** explains each type in depth: [Maybe](../understanding/maybe/), [Result](../understanding/result/),
  [Task](../understanding/task/) and [Exhaustive matching](../understanding/exhaustive-matching/).
- The [API reference](../api/) lists every function.
- **Background** covers [what is different in Lua](../background/lua-vs-typescript/), the
  [design decisions](../project/design/) and the [strict Luau guide](../project/strict-luau-guide/) the library
  follows.
