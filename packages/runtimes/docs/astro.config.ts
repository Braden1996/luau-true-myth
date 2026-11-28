import starlight from "@astrojs/starlight";
import type { AstroUserConfig } from "astro";
import { defineConfig } from "astro/config";
import starlightLuau from "starlight-luau";

import { projectDocs } from "./scripts/sync-docs.ts";
import { API_MODULES, PROSE_DIRECTORY, SOURCE_DIRECTORY, SPEC_PATTERN } from "./src/lib/api-reference.ts";

const repository = "https://github.com/Braden1996/luau-true-myth";

// Expressive Code's options, including the Luau checking plugin, are in ec.config.mjs.
// https://astro.build/config: fully static output for GitHub Pages (project site under /luau-true-myth/).
const config: AstroUserConfig = defineConfig({
  site: "https://braden1996.github.io",
  base: "/luau-true-myth/",
  trailingSlash: "always",
  output: "static",
  integrations: [
    projectDocs(),
    starlight({
      title: "luau-true-myth",
      description:
        "Maybe, Result and Task for strict Luau: a port of true-myth for Lune scripts and World of Warcraft addons (Lua 5.1).",
      logo: { src: "./src/assets/logo.svg", alt: "" },
      favicon: "/favicon.svg",
      social: [{ icon: "github", label: "GitHub", href: repository }],
      editLink: { baseUrl: `${repository}/edit/main/packages/runtimes/docs/` },
      lastUpdated: true,
      routeMiddleware: "./src/lib/edit-link.ts",
      customCss: ["./src/styles/theme.css"],
      plugins: [
        starlightLuau({
          source: SOURCE_DIRECTORY,
          modules: API_MODULES,
          output: "api",
          sidebar: false,
          prose: PROSE_DIRECTORY,
          examples: { patterns: [SPEC_PATTERN] },
          sourceUrl: `${repository}/blob/main/packages/libraries/luau/pure/true-myth/src/{file}#L{line}`,
        }),
      ],
      sidebar: [
        {
          label: "Introduction",
          items: [
            { slug: "introduction" },
            { slug: "getting-started/install" },
            { slug: "getting-started/editor-setup" },
            { slug: "getting-started/tour" },
          ],
        },
        {
          label: "Understanding",
          items: [
            { slug: "understanding/maybe" },
            { slug: "understanding/result" },
            { slug: "understanding/task" },
            { slug: "understanding/exhaustive-matching" },
            { slug: "understanding/new-solver-tips" },
          ],
        },
        {
          label: "API reference",
          items: [{ autogenerate: { directory: "api" } }],
        },
        {
          label: "Background",
          items: [
            { slug: "background/lua-vs-typescript" },
            { slug: "project/design" },
            { slug: "project/strict-luau-guide" },
          ],
        },
        {
          label: "Project",
          items: [{ slug: "project/contributing" }, { slug: "project/changelog" }],
        },
      ],
    }),
  ],
});

export default config;
