import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";

import { loadModules, MODULE_NAMES, sourcePath } from "./modules.ts";
import { parseModule } from "./parse-luau.ts";
import { renderDoc } from "./render-doc.ts";

describe("parseModule", () => {
  test("reads functions, multi-line signatures, types and the module description", () => {
    const source = [
      "--!strict",
      "--[[",
      "\tDemo: a module.",
      "",
      "\tSecond paragraph.",
      "",
      "\tPorted from true-myth (MIT).",
      "]]",
      "",
      "--- A value.",
      "export type Box<T> = { read value: T }",
      "",
      "export type Wide = {",
      "\t--- not a doc entry",
      "\tread a: number,",
      "}",
      "",
      "--- Removes nil.",
      "export type function NonNil(t: type): type",
      "\treturn t",
      "end",
      "",
      "local Demo = {}",
      "",
      "--- Wraps `value`.",
      "--- Second line.",
      "function Demo.box<T>(value: T): Box<T>",
      "\treturn { value = value }",
      "end",
      "",
      "local function helper() end",
      "",
      "--- Long one.",
      "function Demo.long(",
      "\ta: number,",
      "\tb: (number) -> ()",
      "): number",
      "\treturn a",
      "end",
      "",
      "function Demo.undocumented() end",
      "",
      "return Demo",
    ].join("\n");
    const parsed = parseModule("Demo", source);
    expect(parsed.description).toBe("Demo: a module.\n\nSecond paragraph.");
    expect(parsed.functions.map((entry) => entry.name)).toEqual(["box", "long", "undocumented"]);
    expect(parsed.functions[0]?.doc).toBe("Wraps `value`.\nSecond line.");
    expect(parsed.functions[1]?.signature).toBe(
      "function Demo.long(\n  a: number,\n  b: (number) -> ()\n): number",
    );
    expect(parsed.functions[2]?.doc).toBe("");
    expect(parsed.types.map((entry) => entry.name)).toEqual(["Box", "Wide", "NonNil"]);
    expect(parsed.types[1]?.signature).toBe("type Wide = {\n  read a: number,\n}");
    expect(parsed.types[2]?.signature).toBe("type function NonNil(t: type): type");
  });
});

describe("renderDoc", () => {
  test("escapes HTML, renders code spans and joins wrapped lines", () => {
    expect(renderDoc("Returns `Ok<T>` or\n<nothing>.\n\nSecond.")).toBe(
      "<p>Returns <code>Ok&lt;T&gt;</code> or &lt;nothing&gt;.</p>\n<p>Second.</p>",
    );
  });
});

describe("the library's documentation", () => {
  const modules = loadModules();

  test.each([...MODULE_NAMES])("every public function of %s is parsed and documented", (name) => {
    const source = readFileSync(sourcePath(name), "utf8");
    const declared = source.match(new RegExp(`^function ${name}\\.`, "gmu"))?.length ?? 0;
    const parsed = modules.find((module) => module.name === name);
    expect(parsed?.functions.length).toBe(declared);
    expect(declared).toBeGreaterThan(0);
    const undocumented = parsed?.functions
      .filter((entry) => entry.doc === "")
      .map((entry) => entry.name);
    expect(undocumented).toEqual([]);
    expect(parsed?.description).not.toBe("");
  });
});
