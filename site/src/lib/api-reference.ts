import { fileURLToPath } from "node:url";

export const API_MODULES = ["Maybe", "Result", "Task", "Delay", "Toolbelt", "Exhaustive"];

export const SOURCE_DIRECTORY = "../src";
export const PROSE_DIRECTORY = "../docs/api";
export const SPEC_PATTERN = "../tests/spec/{name}.spec.luau";

export function repositoryPath(relativeToSite: string): string {
  return fileURLToPath(new URL(`../../${relativeToSite}`, import.meta.url));
}
