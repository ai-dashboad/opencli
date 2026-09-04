import { describe, expect, it } from "vitest";

import { shows } from "./abilities";

const all = { query: "", department: null };

describe("the ability filter", () => {
  it("should match a name or its description", () => {
    const slack = { name: "Slack", description: "Read channels and post messages." };
    expect(shows({ ...all, query: "slack" }, slack)).toBe(true);
    expect(shows({ ...all, query: "channels" }, slack)).toBe(true);
    expect(shows({ ...all, query: "shopify" }, slack)).toBe(false);
  });

  it("should ignore case and surrounding space, because people type both", () => {
    const slack = { name: "Slack", description: "" };
    expect(shows({ ...all, query: "  SLACK " }, slack)).toBe(true);
  });

  it("should show only what a department would want", () => {
    const github = { name: "GitHub", departments: ["engineering"] };
    expect(shows({ ...all, department: "engineering" }, github)).toBe(true);
    expect(shows({ ...all, department: "finance" }, github)).toBe(false);
  });

  it("should keep an untagged entry visible under every department", () => {
    // Hiding it under the filter would hide it from everyone at once, and
    // nothing on the screen would say why it had gone.
    const stray = { name: "Something nobody categorised" };
    expect(shows({ ...all, department: "finance" }, stray)).toBe(true);
    expect(shows({ ...all, department: "engineering" }, stray)).toBe(true);
  });

  it("should apply both at once", () => {
    const notion = { name: "Notion", description: "Pages and databases.", departments: ["people"] };
    expect(shows({ query: "notion", department: "people" }, notion)).toBe(true);
    expect(shows({ query: "notion", department: "finance" }, notion)).toBe(false);
    expect(shows({ query: "slack", department: "people" }, notion)).toBe(false);
  });

  it("should show everything when nothing is asked for", () => {
    expect(shows(all, { name: "Anything", departments: ["engineering"] })).toBe(true);
  });
});
