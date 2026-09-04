import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";

import { BotsView } from "./bots-view";
import type { OpenCliClient } from "./protocol";
import { Scenarios } from "./scenario-list";

/**
 * Proof that the first screen renders, rather than an argument that it should.
 *
 * There is no DOM here, so this is the markup React would produce — which is
 * exactly the question being asked: does the panel appear at all, and does it
 * hold the six kinds of work with something under each of them.
 */
describe("the first screen", () => {
  it("should render the kinds of work it can be asked to do", () => {
    const html = renderToStaticMarkup(
      <Scenarios connected={["github"]} onPick={() => {}} onConnect={() => {}} />,
    );

    expect(html).toContain("Things it can do for you");
    for (const name of [
      "Watching messages",
      "Social media",
      "Selling abroad",
      "Your own audience",
      "Finding customers",
      "Doing it on a schedule",
    ]) {
      expect(html, `${name} is missing from the first screen`).toContain(name);
    }
  });

  it("should show the instructions once a kind of work is opened", () => {
    // Closed to begin with, so the six read as a menu rather than a wall.
    const closed = renderToStaticMarkup(
      <Scenarios connected={[]} onPick={() => {}} onConnect={() => {}} />,
    );
    expect(closed).not.toContain("Shrink every image in this folder");
  });
});

describe("the bots page", () => {
  const client = {
    listQuestions: async () => [],
    listChains: async () => ({ chains: [], maxHops: 8 }),
  } as unknown as OpenCliClient;

  it("should render its two sections before anything has loaded", () => {
    // Server-rendered, so this is the first paint: what somebody sees while
    // the two requests are still out. Blank until they answer would read as a
    // page that had failed.
    const html = renderToStaticMarkup(<BotsView client={client} />);

    expect(html).toContain("Waiting on you");
    expect(html).toContain("Work passed between bots");
  });

  it("should say plainly that nothing is waiting rather than showing nothing", () => {
    const html = renderToStaticMarkup(<BotsView client={client} />);
    expect(html).toContain("Nothing is waiting");
    expect(html).toContain("No bot has handed work to another yet");
  });
});
