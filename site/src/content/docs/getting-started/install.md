---
title: Install
description: Add luau-true-myth to a Lune project, a Luau WoW addon, or a plain-Lua WoW addon.
---

The library is the `src/` folder: Luau modules with no dependencies. Pick the way that matches your project.

## Lune and other Luau projects

Copy `src/` from a [release](https://github.com/Braden1996/luau-true-myth/releases/latest)
(`luau-true-myth-<version>.zip`) or add the repository as a git submodule, then require one module or the entry
point:

```luau
local TrueMyth = require("./vendor/luau-true-myth/src/TrueMyth")
local Maybe, Result, Task = TrueMyth.Maybe, TrueMyth.Result, TrueMyth.Task
type Result<T, E> = TrueMyth.Result<T, E>
```

## WoW addons written in Luau

If you compile your addon with [darklua](https://darklua.com) (as the
[wow-forever-luau-types](https://github.com/Braden1996/wow-forever-luau-types) template does), vendor `src/` as
above. darklua's `bundle` rule inlines it into your addon's file. The library uses only Lua 5.1 library functions,
and CI checks that.

## WoW addons written in plain Lua

Download `TrueMyth.lua` from the latest release (checksums are in `SHA256SUMS`) and list it in your `.toc` before
your own files. It stores the library in your addon's private namespace and creates no global:

```lua
local _, ns = ...
local Result = ns.TrueMyth.Result
```

## Versions

Pin a release. Releases follow semantic versioning: a minor version for anything that can break existing code,
including stricter types. The [changelog](../../project/changelog/) lists every change.
