# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

## [0.2.0] - 2026-11-27

### Added

- A documentation site on GitHub Pages (<https://braden1996.github.io/luau-true-myth/>): guides, an API reference
  generated from the types by `starlight-luau`, and the design notes and strict Luau guide. Astro and
  Starlight, with strict TypeScript 7, oxlint and oxfmt, in `site/`.
- Checked guide examples (` ```luau check `) type-checked against the library at build time by
  [luau-web-checker](https://github.com/Braden1996/luau-web-checker) with hover types.
- `woof.toml` package manifest and `woof`-native release archives (`luau-true-myth-0.2.0.zip`, with `woof.toml` and
  `src/` at archive root) alongside `TrueMyth.lua` and `SHA256SUMS`.
- Colocated specs (`Show.spec.luau`, `scripts/lint/rules.spec.luau`, `scripts/fixtures/diagnostics.spec.luau`) and
  fast parallel LuaJIT test execution with Sergeant symbol-level caching (`sgt test`).

### Changed

- **Breaking (repository layout / conventions):** Replaced comments in Luau code with descriptive names, small
  functions, and colocated specs (`*.spec.luau`); `:: any` casts live only in `unchecked*` functions.
- Migrated workspace orchestration, formatting, linting, strict Lua 5.1 static analysis, and test execution from
  `moon` and `dprint` to [Sergeant](https://github.com/Braden1996/sergeant) (`v0.14.0`) with the `luau`, `lune`,
  `woof`, `actionlint`, `zizmor`, and `lychee` plugins.
- Moved the library sources into `packages/true-myth/src/` (`@luau-true-myth/true-myth`) and the test harness into
  `packages/test-harness/src/` (`@luau-true-myth/test-harness`). Release archives still ship runtime files under `src/`.

## [0.1.0] - 2026-11-15

### Added

- `Maybe`, `Result` and `Task`: a strict-Luau port of true-myth as plain, read-only tagged tables with module
  functions. Values are serialisable and narrow on `kind`.
- Generic signatures that infer cleanly on Luau's new solver: whole-type generics with the `OkOf`, `ErrOf`,
  `ValueOf` and `ReasonOf` type functions. Error types compose through `andThen`.
- `Task` without promises: synchronous settlement, coroutine-based `async`/`await`, an injected `Schedule` for
  `timer`, `timeout` and `withRetries`, and typed early stop through `shouldRetry`.
- `Delay` retry strategies, `Toolbelt` conversions between `Maybe` and `Result`, and `Exhaustive.casesHandled`
  for compile-time exhaustiveness.
- `dist/TrueMyth.lua`: a Lua 5.1 bundle for WoW addons. In a `.toc` it stores the library as `ns.TrueMyth`.
- Specs run against the Luau sources and against the bundle in a Lua 5.1-only environment, with an API coverage
  check. Type fixtures pin luau-lsp's exact diagnostics.
- The strict Luau guide, a design document, CI, a tag-triggered release with checksums,
  Dependabot for actions, and VS Code and Zed settings.

[Unreleased]: https://github.com/Braden1996/luau-true-myth/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Braden1996/luau-true-myth/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Braden1996/luau-true-myth/releases/tag/v0.1.0
