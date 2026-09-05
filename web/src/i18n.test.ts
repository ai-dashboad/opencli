import { describe, expect, it } from "vitest";

import { addLocales, getLocale, locales, setLocale, t } from "./i18n";

/**
 * Languages added on the machine running this, rather than in the build.
 *
 * These share one module-level dictionary, so each test uses its own language
 * code. That is not a workaround: the dictionary is deliberately global — the
 * interface asks `t()` from hundreds of places and threading a dictionary
 * through all of them would be the tail wagging the dog.
 */
describe("added languages", () => {
  it("should offer a language that was added", () => {
    addLocales([{ code: "xx-offer", name: "Testish", strings: { Dispatch: "Sendish" } }]);
    expect(locales().map((each) => each.value)).toContain("xx-offer");
    expect(locales().find((each) => each.value === "xx-offer")?.label).toBe("Testish");
  });

  it("should use an added translation once that language is chosen", () => {
    addLocales([{ code: "xx-use", name: "Testish", strings: { Dispatch: "Sendish" } }]);
    setLocale("xx-use");
    expect(t("Dispatch")).toBe("Sendish");
    setLocale("en");
  });

  it("should show the English when the added language does not translate it", () => {
    // A half-finished translation should read as a mix, not as a hole.
    addLocales([{ code: "xx-partial", name: "Testish", strings: { Dispatch: "Sendish" } }]);
    setLocale("xx-partial");
    expect(t("Memory")).toBe("Memory");
    setLocale("en");
  });

  it("should correct a shipped language rather than replacing it", () => {
    // The point of merging: changing one awkward sentence must not cost the
    // other four hundred.
    addLocales([{ code: "zh", name: "", strings: { Dispatch: "派活儿" } }]);
    setLocale("zh");
    expect(t("Dispatch")).toBe("派活儿");
    expect(t("Memory")).toBe("记忆");
    setLocale("en");
  });

  it("should keep a shipped language's own name when the file gives none", () => {
    addLocales([{ code: "zh", name: "", strings: {} }]);
    expect(locales().find((each) => each.value === "zh")?.label).toBe("中文");
  });

  it("should fill in the numbers an added sentence asks for", () => {
    addLocales([{ code: "xx-vars", name: "Testish", strings: { "Runs ({count})": "跑了 {count} 次" } }]);
    setLocale("xx-vars");
    expect(t("Runs ({count})", { count: 42 })).toBe("跑了 42 次");
    setLocale("en");
  });

  it("should ignore an entry with no code", () => {
    const before = locales().length;
    addLocales([{ code: "", name: "Nowhere", strings: { Dispatch: "x" } }]);
    expect(locales().length).toBe(before);
  });

  it("should leave the chosen language alone while adding others", () => {
    setLocale("en");
    addLocales([{ code: "xx-quiet", name: "Testish", strings: { Dispatch: "Sendish" } }]);
    expect(getLocale()).toBe("en");
    expect(t("Dispatch")).toBe("Dispatch");
  });
});
