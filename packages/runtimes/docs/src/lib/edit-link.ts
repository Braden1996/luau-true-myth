import type {} from "@astrojs/starlight";
import { defineRouteMiddleware } from "@astrojs/starlight/route-data";

export const onRequest = defineRouteMiddleware((context) => {
  const { editUrl } = context.locals.starlightRoute;
  if (editUrl?.pathname.includes("/.astro/staged-src/")) {
    editUrl.pathname = editUrl.pathname.replace("/.astro/staged-src/", "/src/");
  }
});
