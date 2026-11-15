# Contributing

Thanks for helping. Issues and pull requests are welcome, from one-line fixes to new functions.

## Setup

1. Install [mise](https://mise.jdx.dev). `mise install` installs every pinned tool: moon, Lune, luau-lsp, StyLua,
   selene, darklua, typos, actionlint, dprint, lychee and lefthook (versions in `mise.toml`, checksums in
   `mise.lock`).
2. `mise exec -- lefthook install` installs the git hooks: formatting and spelling on commit, `moon run :check` for
   the changed projects on push. Never bypass them with `--no-verify`.
3. `mise exec -- moon run lib:lune-types` writes Lune's type definitions, which `.luaurc`'s `@lune` alias needs.
4. Open the folder in **VS Code** (install the recommended extensions; `.vscode/tasks.json` runs the moon targets)
   or **Zed** (install the "Luau" extension). Both are set up for luau-lsp on the new type solver.

## Tasks

[moon](https://moonrepo.dev) runs every task; `moon run :check` is exactly what CI runs.

| Command                                              | What it does                                                         |
| ---------------------------------------------------- | -------------------------------------------------------------------- |
| `mise exec -- moon run :check`                       | Everything CI runs                                                   |
| `mise exec -- moon run lib:build`                    | Rebuild `dist/TrueMyth.lua` (darklua bundle, checked as Lua 5.1)     |
| `mise exec -- moon run tests:spec`                   | Specs against the Luau sources and the Lua 5.1 bundle, with coverage |
| `mise exec -- moon run tests:fixtures`               | Type fixtures: exact luau-lsp diagnostics                            |
| `mise exec -- moon run repo:fmt lib:fmt`             | Format Markdown/JSON/YAML/TOML (dprint) and Luau (StyLua)            |
| `mise exec -- lune run scripts/fixtures -- --update` | Rewrite the fixtures' `.expected` files after an intended change     |
| `mise exec -- lune run scripts/banner`               | Regenerate `.github/banner.svg`                                      |

## Rules

The code follows the [strict Luau guide](docs/strict-luau-guide.md). In short:

- Every file starts with `--!strict` and type-checks on the new solver.
- `:: any` needs a `-- SAFETY:` comment explaining why it holds (the lint enforces it).
- Code in `src/` ships to Lua 5.1: no Luau-only library functions, no generalized iteration, no string
  interpolation (the lint enforces it, and the specs run against the bundle in a Lua 5.1-only environment).
- Expected failures are returned as values. `error()` is only for defects.
- Every public function has a doc comment and a spec. The test runner fails on a function no spec calls.
- A change to a type's behaviour needs a fixture: a positive one in `tests/pass/` or a negative one with
  `-- expect-error:` markers in `tests/fail/`.
- Never edit `dist/TrueMyth.lua` or `.github/banner.svg` by hand. CI fails if they differ from a fresh build.

## Dependencies

- **GitHub Actions:** Dependabot opens grouped pull requests for the SHA-pinned actions.
- **Tools:** edit the version in `mise.toml`, then `mise lock` and `moon run :check`. A luau-lsp bump can change
  diagnostics: run `lune run scripts/fixtures -- --update` and review the `.expected` diff.

## Pull requests

- One concern per pull request.
- Title: `type(scope): summary`, checked by CI. Types: feat fix perf refactor test docs build ci chore style revert.
  Scopes: maybe result task delay toolbelt exhaustive bundle tests ci docs deps repo.
- Note user-visible changes in `CHANGELOG.md` under "Unreleased".

## Releases

Maintainers move the "Unreleased" notes in `CHANGELOG.md` under a version heading, set `version` in
`src/TrueMyth.luau`, rebuild (`moon run lib:build`, `lune run scripts/banner`), then tag `vX.Y.Z` on `main`. The
release workflow re-runs `moon run :check` from a cold start, checks the tag matches `version`, and publishes
`TrueMyth.lua`, a source archive and `SHA256SUMS`.

## Conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
