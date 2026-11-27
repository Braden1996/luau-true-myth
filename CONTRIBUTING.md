# Contributing

Thanks for helping. Issues and pull requests are welcome, from one-line fixes to new functions.

## Setup

1. Install [mise](https://mise.jdx.dev). `mise install` installs every pinned tool: Sergeant (`sgt`), `woof`, Lune,
   luau-lsp, StyLua, selene, darklua, typos, actionlint, zizmor, lychee, lefthook, Bun, Node, and `luau-ast` (versions
   in `mise.toml`, checksums in `mise.lock`). Ensure `luajit` is available on `PATH` for `sgt test`.
2. `mise exec -- lefthook install` installs the git hooks: formatting and spelling on commit, `sgt check && sgt test` on
   push. Never bypass them with `--no-verify`.
3. `mise exec -- lune setup` writes Lune's type definitions, which `.luaurc`'s `@lune` alias needs.
4. Open the folder in **VS Code** (install the recommended extensions; `.vscode/tasks.json` runs the Sergeant targets)
   or **Zed** (install the "Luau" extension). Both are set up for luau-lsp on the new type solver.

## Tasks

[Sergeant](https://github.com/Braden1996/sergeant) (`sgt`) orchestrates checks, tests, and commands:

| Command                                | What it does                                                           |
| -------------------------------------- | ---------------------------------------------------------------------- |
| `mise exec -- sgt check`               | Format, lint, strict Lua 5.1 analysis, boundaries, and hermetic checks |
| `mise exec -- sgt test`                | Run all colocated `*.spec.luau` suites on LuaJIT with symbol caching   |
| `mise exec -- sgt doctor`              | Verify toolchain, workspace config, and `woof` state                   |
| `mise exec -- sgt run build`           | Rebuild `dist/TrueMyth.lua` (darklua bundle, checked as Lua 5.1)       |
| `mise exec -- sgt run bundle-specs`    | Specs against Luau sources and Lua 5.1 bundle, with 100% coverage      |
| `mise exec -- sgt run fixtures`        | Type fixtures: exact luau-lsp diagnostics                              |
| `mise exec -- sgt fmt`                 | Format Markdown/JSON/YAML/TOML and Luau                                |
| `mise exec -- sgt run fixtures-update` | Rewrite the fixtures' `.expected` files after an intended change       |
| `mise exec -- sgt run banner`          | Regenerate `.github/banner.svg`                                        |
| `mise exec -- sgt run site-check`      | The docs site: typecheck, lint, format, tests and build                |

## The documentation site

`site/` is an [Astro](https://astro.build) + [Starlight](https://starlight.astro.build) site deployed to GitHub
Pages from `main`. Bun and Node come from `mise.toml`. In `site/`, `mise exec -- bun install` then `bun run dev`
serves it locally.

- **API pages** are generated from the Luau types in `packages/true-myth/src/` by
  [starlight-luau](https://github.com/Braden1996/starlight-luau), with examples from `packages/true-myth/src/*.spec.luau`
  and hand-written prose from `docs/api/` (`Result.md`, `Result/map.md`, `Result/types/Ok.md`). A test fails if a public
  function has no prose file. The `luau-ast` tool it needs comes from `mise.toml`.
- **Design, guide, contributing and changelog pages** are copied from the repository's Markdown by
  `site/scripts/sync-docs.ts`. Edit the originals.
- **Guides** live in `site/src/content/docs/`.
- TypeScript uses the strictest settings (TypeScript 7 `tsgo` plus `astro check`), and oxlint (type-aware) and oxfmt
  check it.

## Rules

The code follows the [strict Luau guide](docs/strict-luau-guide.md). In short:

- Every file starts with `--!strict` and type-checks on the new solver.
- No comments in Luau code: use descriptive names, small functions and tests. The lint rejects comments other than
  `--!strict` and the fixtures' `-- expect-error:` markers.
- `:: any` only inside a small function named `unchecked…` that says what it assumes (the lint enforces it).
- Code in `packages/true-myth/src/` ships to Lua 5.1: no Luau-only library functions, no generalized iteration, no string
  interpolation (enforced by Sergeant's `target: "lua51"` and `scripts/lint`, and tested on LuaJIT).
- Expected failures are returned as values. `error()` is only for defects.
- Every module has a colocated spec (`Result.luau` and `Result.spec.luau`), and every public function is called by one.
  Tooling in `scripts/` has colocated specs too (`scripts/lint/rules.spec.luau`), checked by `sgt check`.
- A change to a type's behaviour needs a fixture: a positive one in `tests/pass/` or a negative one with
  `-- expect-error:` markers in `tests/fail/`.
- Never edit `dist/TrueMyth.lua` or `.github/banner.svg` by hand. CI fails if they differ from a fresh build.

## Dependencies

- **GitHub Actions:** Dependabot opens grouped pull requests for the SHA-pinned actions.
- **Tools:** edit the version in `mise.toml`, then `mise lock` and `sgt check`. A luau-lsp bump can change
  diagnostics: run `sgt run fixtures-update` and review the `.expected` diff.

## Pull requests

- One concern per pull request.
- Title: `type(scope): summary`, checked by CI. Types: feat fix perf refactor test docs build ci chore style revert.
  Scopes: maybe result task delay toolbelt exhaustive bundle tests ci docs deps repo.
- Note user-visible changes in `CHANGELOG.md` under "Unreleased".

## Releases

Maintainers move the "Unreleased" notes in `CHANGELOG.md` under a version heading, set `version` in
`packages/true-myth/src/TrueMyth.luau` and `woof.toml`, rebuild (`sgt run build`, `sgt run banner`), then tag `vX.Y.Z`
on `main`. The release workflow re-runs the full Sergeant gate from a cold start, checks the tag matches both versions,
and publishes `TrueMyth.lua`, a `woof`-native source archive (`luau-true-myth-X.Y.Z.zip`), and `SHA256SUMS`.

## Conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
