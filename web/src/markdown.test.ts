import { describe, expect, it } from "vitest";
import { parseBlocks, parseInline } from "./markdown";

describe("inline markup", () => {
  it("should read the emphasis an agent actually writes", () => {
    // Straight from a real reply: bold headings and code spans around file
    // names, both of which were being shown as their own asterisks and
    // backticks.
    expect(parseInline("**Test results** (`flutter-skill`, v0.9.37)")).toEqual([
      { kind: "bold", text: "Test results" },
      { kind: "text", text: " (" },
      { kind: "code", text: "flutter-skill" },
      { kind: "text", text: ", v0.9.37)" },
    ]);
  });

  it("should leave markup inside a code span alone", () => {
    // Backticks suppress everything, which is why code is tried first. An
    // agent explaining `**bold**` must be able to write it.
    expect(parseInline("write `**bold**` for emphasis")).toEqual([
      { kind: "text", text: "write " },
      { kind: "code", text: "**bold**" },
      { kind: "text", text: " for emphasis" },
    ]);
  });

  it("should not read a bold marker as two empty italics", () => {
    expect(parseInline("**both**")).toEqual([{ kind: "bold", text: "both" }]);
  });

  it("should not treat a multiplication or a filename as italics", () => {
    // `2 * 3 * 4` and `a*b*c` are text; only a marker with no word character
    // before it opens emphasis.
    expect(parseInline("run 2 * 3 * 4")).toEqual([{ kind: "text", text: "run 2 * 3 * 4" }]);
    expect(parseInline("name*with*stars")).toEqual([
      { kind: "text", text: "name*with*stars" },
    ]);
  });

  it("should follow a link that goes somewhere a browser can go", () => {
    expect(parseInline("see [the docs](https://example.com/x)")).toEqual([
      { kind: "text", text: "see " },
      { kind: "link", text: "the docs", href: "https://example.com/x" },
    ]);
  });

  it("should refuse a link that is not a web address", () => {
    // The one place a model's output would reach an attribute, and so the one
    // place this could turn output into behaviour. Shown as the words it
    // wrote, never made clickable.
    for (const href of ["javascript:alert(1)", "data:text/html,x", "/local/path"]) {
      const runs = parseInline(`[click](${href})`);
      expect(runs.some((run) => run.kind === "link")).toBe(false);
      expect(runs.map((run) => run.text).join("")).toContain("click");
    }
  });

  it("should leave plain text entirely alone", () => {
    const plain = "Working tree clean again. Testing is done — results:";
    expect(parseInline(plain)).toEqual([{ kind: "text", text: plain }]);
  });
});

describe("blocks", () => {
  it("should keep a fenced block whole, markers and all", () => {
    const blocks = parseBlocks("before\n\n```rust\nlet x = 1;\n\nlet y = 2;\n```\n\nafter");
    expect(blocks[1]).toEqual({ kind: "code", text: "let x = 1;\n\nlet y = 2;", language: "rust" });
    expect(blocks[2]).toEqual({ kind: "paragraph", lines: ["after"] });
  });

  it("should close a fence that was never closed", () => {
    // A reply still being written is cut off mid-block more often than not.
    const blocks = parseBlocks("```\nhalf a comm");
    expect(blocks).toEqual([{ kind: "code", text: "half a comm", language: undefined }]);
  });

  it("should gather a run of bullets into one list", () => {
    const blocks = parseBlocks("Results:\n- 5/5 pass\n- 66/66 pass\n\nDone.");
    expect(blocks[1]).toEqual({ kind: "list", ordered: false, items: ["5/5 pass", "66/66 pass"] });
    expect(blocks[2]).toEqual({ kind: "paragraph", lines: ["Done."] });
  });

  it("should tell a numbered list from a bulleted one", () => {
    expect(parseBlocks("1. first\n2. second")).toEqual([
      { kind: "list", ordered: true, items: ["first", "second"] },
    ]);
  });

  it("should read a heading and its level", () => {
    expect(parseBlocks("### Side effect fixed")).toEqual([
      { kind: "heading", level: 3, text: "Side effect fixed" },
    ]);
  });

  it("should keep the line breaks inside a paragraph", () => {
    // An agent writes a line per point without a blank line between them;
    // joining those into one run would lose the shape it wrote.
    expect(parseBlocks("one thing\nanother thing")).toEqual([
      { kind: "paragraph", lines: ["one thing", "another thing"] },
    ]);
  });

  it("should treat what it does not understand as text", () => {
    // A table shown as its own pipes is more readable than one rendered
    // wrongly, so it stays a paragraph.
    const table = "| a | b |\n| - | - |";
    expect(parseBlocks(table)).toEqual([{ kind: "paragraph", lines: ["| a | b |", "| - | - |"] }]);
  });
});
