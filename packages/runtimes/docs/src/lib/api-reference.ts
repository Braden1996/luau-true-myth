import { fileURLToPath } from "node:url";

export const API_MODULES: string[] = ["Maybe", "Result", "Task", "Delay", "Toolbelt", "Exhaustive"];

export const SOURCE_DIRECTORY = "../../libraries/luau/pure/true-myth/src";
export const PROSE_DIRECTORY = "../../../docs/api";
export const SPEC_PATTERN: string = SOURCE_DIRECTORY + "/{name}.spec.luau";

export function docsPath(relativeToSite: string): string {
  return fileURLToPath(new URL(`../../${relativeToSite}`, import.meta.url));
}
