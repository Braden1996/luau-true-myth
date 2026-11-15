## What and why

<!-- One concern per pull request. Title: type(scope): summary. -->

## Checklist

- [ ] `mise exec -- moon run :check` passes locally
- [ ] `dist/TrueMyth.lua` and `.github/banner.svg` were regenerated (`moon run lib:build`, `lune run scripts/banner`), not edited by hand
- [ ] Every new public function has a spec (the API coverage check enforces it) and, if its types are subtle, a fixture
- [ ] `CHANGELOG.md` has a line under "Unreleased" if users will notice the change
