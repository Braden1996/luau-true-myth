// Copies the repository's Markdown documents into the site's content as Starlight pages, so each has one source:
// docs/design.md, docs/strict-luau-guide.md, CONTRIBUTING.md and CHANGELOG.md. The first `# ` heading becomes the
// page title; links between the documents are rewritten to site paths. The output folder is gitignored.
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

interface Document {
  readonly source: string;
  readonly slug: string;
  readonly description: string;
}

const DOCUMENTS: readonly Document[] = [
  {
    source: "docs/design.md",
    slug: "design",
    description: "How luau-true-myth differs from true-myth, and why.",
  },
  {
    source: "docs/strict-luau-guide.md",
    slug: "strict-luau-guide",
    description: "Rules for strict, hard-to-misuse Luau, and the tooling that enforces each one.",
  },
  {
    source: "CONTRIBUTING.md",
    slug: "contributing",
    description: "Setup, tasks, rules and releases for contributors.",
  },
  {
    source: "CHANGELOG.md",
    slug: "changelog",
    description: "Every notable change, by version.",
  },
];

const REPOSITORY = "https://github.com/Braden1996/luau-true-myth/blob/main";
const root = (path: string): string => fileURLToPath(new URL(`../../${path}`, import.meta.url));
const output = fileURLToPath(new URL("../src/content/docs/project/", import.meta.url));

// Links to the other synced documents become site links; other relative links point at GitHub.
function rewriteLinks(markdown: string, from: string): string {
  const directory = from.includes("/") ? from.slice(0, from.lastIndexOf("/") + 1) : "";
  return markdown.replaceAll(
    /\]\((?!https?:|#|mailto:)([^)#]+)(#[^)]*)?\)/gu,
    (_match, target: string, hash = "") => {
      const resolved = new URL(target, `file:///${directory}`).pathname.slice(1);
      const synced = DOCUMENTS.find((document) => document.source === resolved);
      const href = synced ? `../${synced.slug}/` : `${REPOSITORY}/${resolved}`;
      return `](${href}${String(hash)})`;
    },
  );
}

rmSync(output, { force: true, recursive: true });
mkdirSync(output, { recursive: true });
for (const document of DOCUMENTS) {
  const text = readFileSync(root(document.source), "utf8").replaceAll("\r\n", "\n");
  const heading = /^# (.+)\n+/u.exec(text);
  const title = heading?.[1] ?? document.slug;
  const body = heading ? text.slice(heading[0].length) : text;
  const frontmatter = [
    "---",
    `title: ${JSON.stringify(title)}`,
    `description: ${JSON.stringify(document.description)}`,
    `editUrl: ${JSON.stringify(`${REPOSITORY.replace("/blob/", "/edit/")}/${document.source}`)}`,
    "---",
    "",
    `<!-- Generated from ${document.source} by site/scripts/sync-docs.ts; edit that file instead. -->`,
    "",
  ].join("\n");
  writeFileSync(`${output}${document.slug}.md`, frontmatter + rewriteLinks(body, document.source));
}
console.log(`synced ${DOCUMENTS.length} documents into src/content/docs/project/`);
