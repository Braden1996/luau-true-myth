// sgt:whole-files
import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { API_MODULES, PROSE_DIRECTORY, docsPath, SOURCE_DIRECTORY } from "./api-reference.ts";

function publicFunctions(module: string): readonly string[] {
  const source = readFileSync(join(docsPath(SOURCE_DIRECTORY), `${module}.luau`), "utf8");
  return [...source.matchAll(/^function \w+[.:](\w+)/gmu)].map((match) => match[1] ?? "");
}

describe.each(API_MODULES)("the %s API page", (module) => {
  const prose = join(docsPath(PROSE_DIRECTORY), module);

  test("has a module description", () => {
    expect(existsSync(`${prose}.md`)).toBe(true);
  });

  test.each(publicFunctions(module))("explains %s", (name) => {
    expect(existsSync(join(prose, `${name}.md`))).toBe(true);
  });
});
