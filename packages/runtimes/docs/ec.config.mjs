// Expressive Code options. They live here, not in astro.config.ts, because a plugin is not serializable.
// Code blocks marked ```luau check are type-checked as the site builds, against the library itself, by
// luau-web-checker (Luau's own checker, new solver), and their identifiers show their types on hover.
import { defineEcConfig } from "@astrojs/starlight/expressive-code";
import { pluginLuauTypes } from "luau-web-checker/expressive-code";

import { docsChecker, PRELUDE } from "./src/lib/luau/checker.ts";

export default defineEcConfig({
  themes: ["github-dark-default", "github-light-default"],
  plugins: [pluginLuauTypes({ checker: docsChecker, check: "marked", prelude: PRELUDE })],
});
