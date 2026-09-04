import { describe, expect, it } from "vitest";

import {
  SCENARIOS,
  allNeeds,
  findScenario,
  isRunnable,
  missingFor,
  scenariosNeeding,
} from "./scenarios";

describe("SCENARIOS", () => {
  it("should give every kind of work something that runs with nothing connected", () => {
    // The promise the first screen makes. Someone who has just installed this
    // has no accounts wired up, and a screen of work they cannot do teaches
    // them the agent does not work.
    for (const scenario of SCENARIOS) {
      const free = scenario.examples.filter((example) => !example.needs?.length);
      expect(free.length, `${scenario.id} has nothing runnable out of the box`).toBeGreaterThan(0);
    }
  });

  it("should say what each kind of work is, and how to ask for it", () => {
    for (const scenario of SCENARIOS) {
      expect(scenario.name()).not.toHaveLength(0);
      expect(scenario.blurb()).not.toHaveLength(0);
      expect(scenario.examples.length).toBeGreaterThanOrEqual(2);
      for (const example of scenario.examples) {
        expect(example.prompt()).not.toHaveLength(0);
      }
    }
  });

  it("should not offer the same instruction under two headings", () => {
    const prompts = SCENARIOS.flatMap((scenario) =>
      scenario.examples.map((example) => example.prompt()),
    );
    expect(new Set(prompts).size).toBe(prompts.length);
  });
});

describe("isRunnable", () => {
  const needsMail = { prompt: () => "read my mail", needs: ["gmail"] };

  it("should run anything that needs nothing", () => {
    expect(isRunnable({ prompt: () => "shrink these images" }, [])).toBe(true);
  });

  it("should hold back work whose service is not connected", () => {
    expect(isRunnable(needsMail, ["github"])).toBe(false);
    expect(missingFor(needsMail, ["github"])).toEqual(["gmail"]);
  });

  it("should recognise a service whatever it was named", () => {
    // Told to connect something already connected is the kind of wrongness
    // that makes a screen stop being believed.
    expect(isRunnable(needsMail, ["Gmail"])).toBe(true);
    expect(isRunnable(needsMail, ["google-gmail"])).toBe(true);
  });

  it("should require every service a piece of work names", () => {
    const both = { prompt: () => "cross-post", needs: ["slack", "shopify"] };
    expect(isRunnable(both, ["slack"])).toBe(false);
    expect(missingFor(both, ["slack"])).toEqual(["shopify"]);
    expect(isRunnable(both, ["slack", "shopify"])).toBe(true);
  });
});

describe("scenariosNeeding", () => {
  it("should say which kinds of work a service opens up", () => {
    // The Connectors panel reads the other way round from this table: a row
    // that says `postgres` should be able to say why anyone would want it.
    const names = scenariosNeeding("postgres").map((scenario) => scenario.id);
    expect(names).toEqual(["commerce"]);
  });

  it("should match a service however it was named", () => {
    // Slack opens up two of these, and the Connectors panel says so: one
    // service is worth having for more than one reason.
    expect(scenariosNeeding("my-slack").map((s) => s.id)).toEqual(["messages", "community"]);
  });

  it("should say nothing for a service no work asks for", () => {
    expect(scenariosNeeding("figma")).toEqual([]);
  });

  it("should list every service the table asks for, once", () => {
    const needs = allNeeds();
    expect(new Set(needs).size).toBe(needs.length);
    // Everything here is in the connector catalogue, which
    // `scripts/connector-check.py` holds to permanently.
    expect(needs).toContain("slack");
    expect(needs).toContain("postgres");
  });
});

describe("findScenario", () => {
  it("should find each kind of work by its id", () => {
    for (const scenario of SCENARIOS) {
      expect(findScenario(scenario.id)?.id).toBe(scenario.id);
    }
  });

  it("should find nothing for an id that is not one", () => {
    expect(findScenario("no-such-thing")).toBeUndefined();
  });
});
