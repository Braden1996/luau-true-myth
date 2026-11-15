import starlight from "@astrojs/starlight";
import { defineConfig } from "astro/config";

const repository = "https://github.com/Braden1996/luau-true-myth";

// https://astro.build/config: fully static output for GitHub Pages (project site under /luau-true-myth/).
export default defineConfig({
  site: "https://braden1996.github.io",
  base: "/luau-true-myth/",
  trailingSlash: "always",
  output: "static",
  integrations: [
    starlight({
      title: "luau-true-myth",
      description:
        "Maybe, Result and Task for strict Luau: a port of true-myth for Lune scripts and World of Warcraft addons (Lua 5.1).",
      logo: { src: "./src/assets/logo.svg", alt: "" },
      favicon: "/favicon.svg",
      social: [{ icon: "github", label: "GitHub", href: repository }],
      editLink: { baseUrl: `${repository}/edit/main/site/` },
      lastUpdated: true,
      customCss: ["./src/styles/theme.css"],
      expressiveCode: {
        themes: ["github-dark-default", "github-light-default"],
      },
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
          items: [
            { label: "Overview", link: "/api/" },
            { label: "Maybe", link: "/api/maybe/" },
            { label: "Result", link: "/api/result/" },
            { label: "Task", link: "/api/task/" },
            { label: "Delay", link: "/api/delay/" },
            { label: "Toolbelt", link: "/api/toolbelt/" },
            { label: "Exhaustive", link: "/api/exhaustive/" },
          ],
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
