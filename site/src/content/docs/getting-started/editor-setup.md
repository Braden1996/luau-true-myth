---
title: Editor setup
description: Turn on luau-lsp's new type solver, which the library's types need.
---

The library's signatures use type functions, which only Luau's **new type solver** understands. On the old
solver, calls type-check loosely or report errors that are not real.

## VS Code

Install the [Luau Language Server](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp)
extension and add to `.vscode/settings.json`:

```jsonc
{
  "luau-lsp.platform.type": "standard", // not Roblox
  "luau-lsp.sourcemap.enabled": false,
  "luau-lsp.fflags.enableNewSolver": true
}
```

## Zed

Install the "Luau" extension and add to `.zed/settings.json`:

```jsonc
{
  "lsp": {
    "luau-lsp": {
      "settings": {
        "fflags": { "enable_new_solver": true },
        "luau-lsp": { "platform": { "type": "standard" } }
      }
    }
  }
}
```

## Command line and CI

`luau-lsp analyze` exits non-zero on any error, so it can gate a pull request:

```sh
luau-lsp analyze --platform=standard --flag:LuauSolverV2=true src/
```

Pin the luau-lsp version: the new solver changes between releases. This library is tested with luau-lsp 1.70.1.
