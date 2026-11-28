---
title: What is different in Lua
description: How luau-true-myth adapts true-myth's ideas to Lua and Luau, and what is unique to it.
---

true-myth was designed for TypeScript running on JavaScript engines. Lua is a different world: smaller, with no
classes, no promises, and in World of Warcraft a 20-year-old version of the language. This page covers what that
changes. For every decision, with the reasoning, see [Design](../../project/design/).

## Values are data, not objects

true-myth's `Maybe` and `Result` are class instances with methods: `result.map(f)`. Here they are plain tables with
a `kind` tag, and every operation is a module function: `Result.map(result, f)`.

- **They survive saving and loading.** WoW saved variables and JSON keep plain tables but drop metatables (Lua's
  classes). A `Result` you save is still a valid `Result` when it is loaded.
- **They compare by content.** `Result.equals` compares two results by what is inside them.
- **The type checker narrows them.** `if r.kind == "Ok" then` tells the checker which variant you have, so it knows
  `r.value` exists.

## One library, two very different runtimes

- **Lune** runs modern Luau, with its full standard library.
- **World of Warcraft** runs Lua 5.1, with none of Luau's additions.

The library is written in Luau, and a compiler (darklua) turns it into plain Lua 5.1 for WoW. Using only what both
runtimes have is easy to get wrong, so it is checked three ways: a lint on the source, a lint on the compiled file,
and the full test suite running against the compiled file in an environment with only Lua 5.1's functions.

## Async on coroutines, with the clock passed in

JavaScript has promises and an event loop. Lua has neither, so `Task` is built differently:

- A task settles once. Anything waiting on it runs as soon as it settles, without a scheduler.
- `Task.async` and `Task.await` use Lua coroutines to give you `await`-style code.
- Timeouts and retries need a clock, and only the host has one. You pass it in: `C_Timer.After` in WoW,
  `task.delay` in Lune. This also makes timing easy to test with a fake clock.
- Delays are in seconds, like both hosts use, not milliseconds.

One Lua 5.1 limit to know: a coroutine cannot pause inside `pcall`, so do not `Task.await` inside one in WoW.

## Filling gaps in Luau's type checker

TypeScript checks things that Luau does not, so the library helps in a few places:

- **Exhaustiveness.** Luau does not warn when an `if` chain misses a case, or when you compare against a tag that
  does not exist. `Exhaustive.casesHandled` turns a missed case into a type error.
- **Error types that add up.** Chaining with `Result.andThen` combines the possible errors of each step into the
  result's type, without any annotations.
- **Read-only values.** Every field is marked read-only, so changing a result after it is made is a type error.

## Working with Luau's newer type checker

The library's types need Luau's new type checker (the "new solver"). It is more capable, but still young, and the
most obvious way to write generic functions like `Result.map` trips over one of its bugs. The library's signatures
are written to avoid it, which is why they read the result's whole type and pick the value and error types back out
(`OkOf<R>`, `ErrOf<R>`). You do not need to write anything differently. [Tips for the new solver](../../understanding/new-solver-tips/)
lists the few things to keep in mind.

## What was left out

Some true-myth features do not fit Lua: currying (`map(f)(result)`), promise conversion, `toJSON` (values are
already plain data), and functions that throw on a failure. [Design](../../project/design/#not-ported) lists each
one and why.
