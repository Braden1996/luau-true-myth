// The library's public modules, read from ../src at build time.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { type ApiModule, parseModule } from "./parse-luau.ts";

/** The public modules, in the order the site lists them. Show and TrueMyth are internal or re-exports. */
export const MODULE_NAMES = ["Maybe", "Result", "Task", "Delay", "Toolbelt", "Exhaustive"] as const;

export type ModuleName = (typeof MODULE_NAMES)[number];

/** The path of a module's source file. */
export function sourcePath(name: ModuleName): string {
  return fileURLToPath(new URL(`../../../../src/${name}.luau`, import.meta.url));
}

/** Every public module, parsed from its source. */
export function loadModules(): readonly ApiModule[] {
  return MODULE_NAMES.map((name) => parseModule(name, readFileSync(sourcePath(name), "utf8")));
}

/** The site path of a module's API page. */
export function modulePath(name: string): string {
  return `/api/${name.toLowerCase()}/`;
}
