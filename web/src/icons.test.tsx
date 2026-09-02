import { describe, expect, it } from "vitest";
import type React from "react";
import { WorkingDot } from "./icons";

/**
 * Walk a React element tree and collect every element of a kind.
 *
 * No DOM here, so this checks what will be rendered rather than what is
 * painted. That is the line: it cannot prove the dot is visible, but it can
 * prove the dot is still there — which is what went wrong each time.
 */
function findAll(node: React.ReactNode, type: string): Record<string, unknown>[] {
  if (!node || typeof node !== "object") return [];
  if (Array.isArray(node)) return node.flatMap((child) => findAll(child, type));
  const element = node as { type?: unknown; props?: Record<string, unknown> };
  const children = findAll((element.props?.children ?? null) as React.ReactNode, type);
  return element.type === type ? [element.props ?? {}, ...children] : children;
}

describe("the mark that says the agent is working", () => {
  const rendered = WorkingDot({});

  it("should draw a filled circle, not an empty box for CSS to decorate", () => {
    // It was two animating pseudo-elements on an empty span, and it went
    // missing three times — each time invisibly, because a pseudo-element
    // that fails to paint reports nothing. A filled circle cannot vanish
    // without this failing.
    const dot = findAll(rendered, "circle").find((props) => props.className === "spark-dot");
    expect(dot).toBeDefined();
    expect(dot?.fill).toBe("currentColor");
    expect(Number(dot?.r)).toBeGreaterThan(0);
  });

  it("should take its colour from the text around it", () => {
    // `currentColor` and a class that sets it, rather than a variable read
    // inside a gradient: one fewer thing that can resolve to nothing.
    const svg = findAll(rendered, "svg")[0];
    expect(svg?.className).toBe("spark");
  });

  it("should be hidden from a screen reader, which is told by the words", () => {
    const svg = findAll(rendered, "svg")[0];
    expect(svg?.["aria-hidden"]).toBe("true");
  });
});
