# Contributing

Follow the [Sergeant playbook](https://github.com/Braden1996/sergeant#readme) for tooling, local development, and CI.

- Install the pinned tools with `mise install`, then run `lune setup` and `sgt install`. The Bun workspace uses the Sergeant 0.15.0 config tarballs from a sibling checkout at `../sergeant/dist/npm/`.
- Run `sgt check`, `sgt test`, and `sgt build` before opening a pull request. See the [strict Luau guide](docs/strict-luau-guide.md) for library conventions. Add a colocated spec for public API changes and a case in `tests/pass/` or `tests/fail/` for changes to compiler behavior. Run `sgt run fixtures-update` to refresh expected diagnostics.
- Regenerate the committed Lua 5.1 bundle with `sgt run bundle` and the banner with `sgt run banner`.
- Run `sgt dev @luau-true-myth/docs` to preview the site. Edit guides in `packages/runtimes/docs/src/content/docs/`, API prose in `docs/api/`, and API definitions and examples in `packages/libraries/luau/pure/true-myth/src/`.
- Use Conventional Commits for pull request titles. Allowed scopes are `maybe`, `result`, `task`, `delay`, `toolbelt`, `exhaustive`, `bundle`, `tests`, `site`, `ci`, `docs`, `deps`, `deps-dev`, and `repo`.
- For a release, update the version in `woof.toml` and [TrueMyth.luau](packages/libraries/luau/pure/true-myth/src/TrueMyth.luau), add the version to [CHANGELOG.md](CHANGELOG.md), and regenerate the bundle and banner. Tag the verified commit on `main` as `vX.Y.Z`. The release workflow publishes the Woof package and Lua 5.1 bundle.
