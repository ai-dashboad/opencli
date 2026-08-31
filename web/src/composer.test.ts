import { describe, expect, it } from "vitest";
import { shouldDismiss, shouldSend } from "./composer";

describe("pressing Enter in the composer", () => {
  it("should send a finished message", () => {
    expect(shouldSend({ key: "Enter", shiftKey: false, isComposing: false })).toBe(true);
  });

  it("should not send while an input method is composing", () => {
    // Enter confirms the candidate word. Sending here loses it, and a message
    // needing an IME can never be typed.
    expect(shouldSend({ key: "Enter", shiftKey: false, isComposing: true })).toBe(false);
  });

  it("should add a newline on shift-enter rather than sending", () => {
    expect(shouldSend({ key: "Enter", shiftKey: true, isComposing: false })).toBe(false);
  });

  it("should ignore every other key", () => {
    for (const key of ["a", "Escape", "Tab", "Process"]) {
      expect(shouldSend({ key, shiftKey: false, isComposing: false })).toBe(false);
    }
  });
});

describe("pressing Escape in a search box", () => {
  it("should dismiss it", () => {
    expect(shouldDismiss({ key: "Escape", isComposing: false })).toBe(true);
  });

  it("should not dismiss it while an input method is composing", () => {
    // Escape cancels the candidate list; closing the search would throw away
    // what was half-typed.
    expect(shouldDismiss({ key: "Escape", isComposing: true })).toBe(false);
  });
});
