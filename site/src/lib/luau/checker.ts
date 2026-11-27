// The checker behind the docs' checked code blocks (ec.config.mjs): luau-web-checker in strict mode, with the
// library's modules added where the examples `require` them from (`./vendor/luau-true-myth/src/TrueMyth`) and the
// host APIs the examples call (docs-env.d.luau). Loading happens once per build; the build runs from site/.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { Checker } from "luau-web-checker";

/** Where the examples find the library, as in the install guide. */
export const LIBRARY = "vendor/luau-true-myth/src";

/**
 * Hidden code before every checked block: the library's modules, as the tour introduces them, and the quest log the
 * examples share. A block hides any further setup of its own above a `-- ---cut---` line.
 */
export const PRELUDE = [
  ...["TrueMyth", "Maybe", "Result", "Task"].map(
    (name) => `local ${name} = require("./${LIBRARY}/${name}")`,
  ),
  "type Quest = { id: number, title: string, zone: string, level: number }",
  "local QUESTS: { [number]: Quest } = {}",
].join("\n");

let shared: Promise<Checker> | undefined;

export function docsChecker(): Promise<Checker> {
  shared ??= (async () => {
    const site = process.cwd();
    const checker = await Checker.create({
      definitions: {
        "@docs": readFileSync(join(site, "src", "lib", "luau", "docs-env.d.luau"), "utf8"),
      },
      strict: true,
    });
    const source = join(site, "..", "packages", "true-myth", "src");
    for (const file of readdirSync(source).filter(
      (name) => name.endsWith(".luau") && !name.includes(".spec."),
    )) {
      checker.setSource(`${LIBRARY}/${file}`, readFileSync(join(source, file), "utf8"));
    }
    return checker;
  })();
  return shared;
}
