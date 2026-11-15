// Reads a library module's public API from its Luau source: the leading `--[[ ... ]]` block is the module's
// description, and each `function Module.name` or `export type` preceded by `---` lines is an entry. The doc
// comments in src/ are the single source; the site never restates them.

/** One documented public function or exported type. */
export interface ApiEntry {
  readonly kind: "function" | "type";
  readonly name: string;
  /** The declaration as written in the source, dedented, without the body. */
  readonly signature: string;
  /** The `---` comment above the declaration, without the markers; empty when there is none. */
  readonly doc: string;
}

/** A module's description and public entries, in source order. */
export interface ApiModule {
  readonly name: string;
  readonly description: string;
  readonly functions: readonly ApiEntry[];
  readonly types: readonly ApiEntry[];
}

const DOC_LINE = /^---\s?(.*)$/u;
const BLOCK_START = /^--\[(=*)\[/u;

function count(text: string, pattern: RegExp): number {
  return text.match(pattern)?.length ?? 0;
}

function dedent(lines: readonly string[]): string {
  const indents = lines
    .filter((line) => line.trim() !== "")
    .map((line) => /^\t*/u.exec(line)?.[0].length ?? 0);
  const strip = Math.min(...indents);
  return lines.map((line) => line.slice(strip).replaceAll("\t", "  ")).join("\n");
}

// The module's leading block comment, as paragraphs of plain text (the source wraps at 120 columns).
function readDescription(lines: readonly string[]): string {
  const start = lines.findIndex((line) => BLOCK_START.test(line));
  if (start === -1) {
    return "";
  }
  const end = lines.findIndex((line, index) => index > start && line.trim().startsWith("]"));
  const body = lines.slice(start + 1, end === -1 ? lines.length : end).map((line) => line.trim());
  const paragraphs: string[] = [];
  let current: string[] = [];
  for (const line of body) {
    if (line === "") {
      if (current.length > 0) {
        paragraphs.push(current.join(" "));
      }
      current = [];
    } else {
      current.push(line);
    }
  }
  if (current.length > 0) {
    paragraphs.push(current.join(" "));
  }
  return paragraphs
    .filter((paragraph) => !paragraph.startsWith("Ported from true-myth"))
    .join("\n\n");
}

// Lines from `start` until the brackets opened on them are closed again.
function readBalanced(lines: readonly string[], start: number): { text: string[]; next: number } {
  const text: string[] = [];
  let depth = 0;
  let index = start;
  while (index < lines.length) {
    const line = lines[index] ?? "";
    text.push(line);
    depth += count(line, /[({]/gu) - count(line, /[)}]/gu);
    index += 1;
    if (depth <= 0) {
      break;
    }
  }
  return { text, next: index };
}

/** Parses one module's source. `name` is the module table's name (`Result`). */
export function parseModule(name: string, source: string): ApiModule {
  const lines = source.replaceAll("\r\n", "\n").split("\n");
  const functions: ApiEntry[] = [];
  const types: ApiEntry[] = [];
  let doc: string[] = [];
  let index = 0;
  while (index < lines.length) {
    const line = lines[index] ?? "";
    const docLine = DOC_LINE.exec(line);
    if (docLine) {
      doc.push(docLine[1] ?? "");
      index += 1;
      continue;
    }
    const text = doc.join("\n").trim();
    doc = [];
    if (line.startsWith(`function ${name}.`)) {
      const { text: declaration, next } = readBalanced(lines, index);
      const entryName = /^function \w+\.(\w+)/u.exec(line)?.[1] ?? "";
      functions.push({
        kind: "function",
        name: entryName,
        signature: dedent(declaration),
        doc: text,
      });
      index = next;
    } else if (line.startsWith("export type function ")) {
      const entryName = /^export type function (\w+)/u.exec(line)?.[1] ?? "";
      types.push({
        kind: "type",
        name: entryName,
        signature: line.replace(/^export /u, ""),
        doc: text,
      });
      index += 1;
      while (index < lines.length && lines[index] !== "end") {
        index += 1;
      }
      index += 1;
    } else if (line.startsWith("export type ")) {
      const { text: declaration, next } = readBalanced(lines, index);
      const entryName = /^export type (\w+)/u.exec(line)?.[1] ?? "";
      const signature = dedent(declaration.filter((part) => !part.trim().startsWith("--")));
      types.push({
        kind: "type",
        name: entryName,
        signature: signature.replace(/^export /u, ""),
        doc: text,
      });
      index = next;
    } else {
      index += 1;
    }
  }
  return { name, description: readDescription(lines), functions, types };
}
