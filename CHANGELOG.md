# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

- A documentation site on GitHub Pages (<https://braden1996.github.io/luau-true-myth/>): guides, an API reference
  generated from the doc comments in `src/`, and the design notes and strict Luau guide. Astro and Starlight, with
  strict TypeScript 7, oxlint and oxfmt, in `site/`.

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
- The strict Luau guide, a design document, CI (`moon run :check`), a tag-triggered release with checksums,
  Dependabot for actions, and VS Code and Zed settings.

[Unreleased]: https://github.com/Braden1996/luau-true-myth/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Braden1996/luau-true-myth/releases/tag/v0.1.0
