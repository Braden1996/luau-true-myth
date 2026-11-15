// Renders a doc comment to HTML. The comments use only paragraphs and `code` spans, so this needs no Markdown
// library: everything is escaped first, then backtick spans become <code>.

function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function inline(text: string): string {
  return escapeHtml(text).replaceAll(/`([^`]+)`/gu, "<code>$1</code>");
}

/** Paragraphs (separated by blank lines) with inline code; line breaks inside a paragraph are joined. */
export function renderDoc(doc: string): string {
  return doc
    .split(/\n\s*\n/u)
    .map((paragraph) => paragraph.trim())
    .filter((paragraph) => paragraph !== "")
    .map((paragraph) => `<p>${inline(paragraph.replaceAll(/\s*\n\s*/gu, " "))}</p>`)
    .join("\n");
}
