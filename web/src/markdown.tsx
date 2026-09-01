/**
 * The small part of Markdown an agent actually writes.
 *
 * Agent replies are Markdown and were being shown verbatim, so a summary
 * arrived as `**Test results**` and `` `pubspec.lock` `` rather than as
 * emphasis and code. This renders it.
 *
 * It produces **React elements, never HTML strings**. That is the whole
 * safety argument: nothing here can turn a model's output into markup, so
 * there is no injection to sanitise against and no sanitiser to get wrong.
 * The one place a value reaches an attribute is a link's `href`, which is
 * why only `http` and `https` survive.
 *
 * Deliberately partial. Tables, block quotes, images, footnotes and nested
 * lists are not handled, and are shown as the text they are rather than
 * half-rendered — a wrong rendering of a table is harder to read than none.
 */

import type React from "react";

/** One run of inline text, already classified. */
type Inline =
  | { kind: "text"; text: string }
  | { kind: "code"; text: string }
  | { kind: "bold"; text: string }
  | { kind: "italic"; text: string }
  | { kind: "link"; text: string; href: string };

/**
 * Patterns tried at each position, in this order.
 *
 * Code first because backticks suppress everything inside them, and `**`
 * before `*` because otherwise every bold marker parses as two empty italics.
 */
const INLINE_PATTERNS: { kind: Inline["kind"]; pattern: RegExp }[] = [
  { kind: "code", pattern: /`([^`]+)`/ },
  { kind: "link", pattern: /\[([^\]]+)\]\(([^)\s]+)\)/ },
  // Both require the text inside to begin and end with something other than
  // a space, which is what stops `2 * 3 * 4` becoming an emphasised " 3 ".
  { kind: "bold", pattern: /\*\*(\S|\S[^*]*\S)\*\*/ },
  { kind: "italic", pattern: /(?<![*\w])\*(\S|\S[^*\n]*\S)\*(?!\*)/ },
];

/**
 * Only a link that goes somewhere a browser should follow.
 *
 * `javascript:` and `data:` are the reason this function exists; a relative
 * path is refused too, because there is nothing here for it to be relative to.
 */
function safeHref(href: string): string | null {
  return /^https?:\/\//i.test(href) ? href : null;
}

/** Split a line into its runs of emphasis, code and links. */
export function parseInline(line: string): Inline[] {
  const out: Inline[] = [];
  let rest = line;

  while (rest) {
    let earliest: { at: number; kind: Inline["kind"]; match: RegExpMatchArray } | null = null;
    for (const { kind, pattern } of INLINE_PATTERNS) {
      const match = pattern.exec(rest);
      if (match?.index === undefined) continue;
      if (!earliest || match.index < earliest.at) {
        earliest = { at: match.index, kind, match };
      }
    }

    if (!earliest) {
      out.push({ kind: "text", text: rest });
      break;
    }

    if (earliest.at > 0) out.push({ kind: "text", text: rest.slice(0, earliest.at) });

    const [whole, inner, href] = earliest.match;
    if (earliest.kind === "link") {
      const safe = href ? safeHref(href) : null;
      // A link that leads somewhere unfollowable is shown as what it said,
      // rather than silently dropped or made clickable anyway.
      out.push(safe ? { kind: "link", text: inner, href: safe } : { kind: "text", text: inner });
    } else {
      out.push({ kind: earliest.kind, text: inner } as Inline);
    }

    rest = rest.slice(earliest.at + whole.length);
  }

  // Adjacent plain runs are merged, so a refused link leaves one piece of text
  // rather than the two it was split into.
  return out.reduce<Inline[]>((merged, run) => {
    const last = merged[merged.length - 1];
    if (run.kind === "text" && last?.kind === "text") {
      last.text += run.text;
      return merged;
    }
    merged.push(run);
    return merged;
  }, []);
}

function renderInline(line: string, key: string): React.ReactNode[] {
  return parseInline(line).map((run, index) => {
    const at = `${key}-${index}`;
    switch (run.kind) {
      case "code":
        return <code key={at}>{run.text}</code>;
      case "bold":
        return <strong key={at}>{run.text}</strong>;
      case "italic":
        return <em key={at}>{run.text}</em>;
      case "link":
        return (
          <a key={at} href={run.href} target="_blank" rel="noreferrer noopener">
            {run.text}
          </a>
        );
      default:
        return <span key={at}>{run.text}</span>;
    }
  });
}

/** One thing between blank lines: a paragraph, a list, a heading, a fence. */
type Block =
  | { kind: "paragraph"; lines: string[] }
  | { kind: "heading"; level: number; text: string }
  | { kind: "list"; ordered: boolean; items: string[] }
  | { kind: "code"; text: string; language?: string };

const HEADING = /^(#{1,6})\s+(.*)$/;
const BULLET = /^\s*[-*+]\s+(.*)$/;
const NUMBERED = /^\s*\d+[.)]\s+(.*)$/;
const FENCE = /^\s*```\s*(\S*)\s*$/;

/** Group lines into blocks. */
export function parseBlocks(text: string): Block[] {
  const lines = text.split("\n");
  const blocks: Block[] = [];
  let index = 0;

  while (index < lines.length) {
    const line = lines[index];

    const fence = FENCE.exec(line);
    if (fence) {
      const body: string[] = [];
      index += 1;
      // An unterminated fence runs to the end rather than swallowing the rest
      // as a paragraph: a reply cut off mid-block is common enough while one
      // is still being written.
      while (index < lines.length && !FENCE.test(lines[index])) {
        body.push(lines[index]);
        index += 1;
      }
      index += 1;
      blocks.push({ kind: "code", text: body.join("\n"), language: fence[1] || undefined });
      continue;
    }

    const heading = HEADING.exec(line);
    if (heading) {
      blocks.push({ kind: "heading", level: heading[1].length, text: heading[2] });
      index += 1;
      continue;
    }

    const bullet = BULLET.exec(line);
    const numbered = NUMBERED.exec(line);
    if (bullet || numbered) {
      const ordered = !bullet;
      const items: string[] = [];
      while (index < lines.length) {
        const item = ordered ? NUMBERED.exec(lines[index]) : BULLET.exec(lines[index]);
        if (!item) break;
        items.push(item[1]);
        index += 1;
      }
      blocks.push({ kind: "list", ordered, items });
      continue;
    }

    if (!line.trim()) {
      index += 1;
      continue;
    }

    const paragraph: string[] = [];
    while (
      index < lines.length &&
      lines[index].trim() &&
      !HEADING.test(lines[index]) &&
      !BULLET.test(lines[index]) &&
      !NUMBERED.test(lines[index]) &&
      !FENCE.test(lines[index])
    ) {
      paragraph.push(lines[index]);
      index += 1;
    }
    blocks.push({ kind: "paragraph", lines: paragraph });
  }

  return blocks;
}

export function Markdown({ text }: { text: string }) {
  return (
    <div className="prose">
      {parseBlocks(text).map((block, index) => {
        const key = `b${index}`;
        switch (block.kind) {
          case "code":
            return (
              <pre key={key} className="code-block">
                <code>{block.text}</code>
              </pre>
            );
          case "heading": {
            // Levels are flattened to three: an agent's `####` inside a chat
            // message is not a document outline, and six sizes of heading in a
            // paragraph of prose reads as noise.
            const Tag = (block.level <= 2 ? "h3" : block.level === 3 ? "h4" : "h5") as "h3";
            return <Tag key={key}>{renderInline(block.text, key)}</Tag>;
          }
          case "list": {
            const Tag = block.ordered ? "ol" : "ul";
            return (
              <Tag key={key}>
                {block.items.map((item, at) => (
                  <li key={`${key}-${at}`}>{renderInline(item, `${key}-${at}`)}</li>
                ))}
              </Tag>
            );
          }
          default:
            return (
              <p key={key}>
                {block.lines.map((line, at) => (
                  <span key={`${key}-${at}`}>
                    {renderInline(line, `${key}-${at}`)}
                    {at < block.lines.length - 1 ? "\n" : null}
                  </span>
                ))}
              </p>
            );
        }
      })}
    </div>
  );
}
