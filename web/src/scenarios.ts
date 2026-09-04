/**
 * What this can be asked to do, said in the words of the person asking.
 *
 * The panels name the machinery — artifacts, dispatch, connectors — and
 * someone opening the app for the first time learns from them what the parts
 * are called, not what the thing is for. These are the other half: kinds of
 * work, each with instructions that can be run as they stand.
 *
 * Two rules hold this together, and both exist so that a first attempt
 * succeeds rather than teaching that it does not work:
 *
 * 1. Every scenario carries at least one example that needs nothing — no
 *    account, no key, no connector. Someone who has just installed this can
 *    click it and watch it work.
 * 2. An example that needs a service says so, by name, before it is run.
 *    Offering work that cannot be done is worse than offering none: the
 *    failure is silent and reads as the agent being incapable.
 *
 * Text is wrapped in `t()` at the point of use rather than stored translated,
 * so the locale can change without rebuilding this table — and so the
 * translation check, which reads `t("…")` literals, can see every string here.
 */

import { t } from "./i18n";

/** One instruction, ready to run. */
export interface ScenarioExample {
  prompt: () => string;
  /**
   * Connectors this cannot work without, by the name they are configured
   * under. Absent means it needs nothing but the agent itself.
   */
  needs?: string[];
}

/** A kind of work, and some of the ways to ask for it. */
export interface Scenario {
  id: string;
  name: () => string;
  /** What this kind of work is, in one line. */
  blurb: () => string;
  examples: ScenarioExample[];
  /** A limit worth knowing before trying, where one exists. */
  caveat?: () => string;
}

export const SCENARIOS: Scenario[] = [
  {
    id: "messages",
    name: () => t("Watching messages"),
    blurb: () => t("Keep an eye on what comes in, and draft the replies."),
    // Said here rather than discovered later. The apps that own most Chinese
    // marketplace conversations — Qianniu, Pinduoduo, Douyin — publish no API
    // at all; tools that answer messages there do it by driving the seller's
    // own phone, which is a different thing from what this agent does.
    caveat: () =>
      t(
        "Marketplace apps with no API of their own — Qianniu, Pinduoduo, Douyin — cannot be read from here.",
      ),
    examples: [
      {
        prompt: () =>
          t("Read the questions in questions.csv and draft an answer to each one"),
      },
      {
        prompt: () => t("Summarise the questions in our support channel that nobody has answered"),
        needs: ["slack"],
      },
      {
        prompt: () =>
          t("Every ten minutes, check the support channel and tell me if somebody is waiting"),
        needs: ["slack"],
      },
    ],
  },
  {
    id: "social",
    name: () => t("Social media"),
    blurb: () => t("Write the posts, and watch what is said back."),
    examples: [
      {
        prompt: () =>
          t("Write a week of posts about our new product, one a day, and save them as files"),
      },
      {
        prompt: () => t("Turn this month's changes into an announcement post"),
      },
      {
        prompt: () => t("Find what people said about us in the last day and sort it by mood"),
        needs: ["brave-search"],
      },
    ],
  },
  {
    id: "commerce",
    name: () => t("Selling abroad"),
    blurb: () => t("Listings, orders and stock, across the stores you sell on."),
    examples: [
      {
        prompt: () =>
          t("Translate every product title in products.csv into English and Spanish"),
      },
      {
        prompt: () => t("Rewrite these product descriptions so they read as though written in English"),
      },
      {
        prompt: () => t("List the ten slowest-selling products in the orders table"),
        needs: ["postgres"],
      },
    ],
  },
  {
    id: "community",
    name: () => t("Your own audience"),
    blurb: () => t("Newsletters, announcements, and keeping a list warm."),
    examples: [
      {
        prompt: () => t("Draft this month's newsletter from what changed in the project"),
      },
      {
        prompt: () => t("Split contacts.csv into groups by what each person bought"),
      },
      {
        prompt: () => t("Post this announcement to our channel"),
        needs: ["slack"],
      },
    ],
  },
  {
    id: "leads",
    name: () => t("Finding customers"),
    blurb: () => t("Look for people who might buy, and write to them."),
    examples: [
      {
        prompt: () =>
          t("Find ten companies that sell outdoor gear online and write a short note to each"),
      },
      {
        prompt: () => t("Work out who to contact at each company in this list and put it in a table"),
      },
      {
        prompt: () => t("Check which of these email addresses still work"),
      },
    ],
  },
  {
    id: "automation",
    name: () => t("Doing it on a schedule"),
    blurb: () => t("The jobs you would otherwise remember to do yourself."),
    examples: [
      {
        prompt: () => t("Shrink every image in this folder to under 200KB"),
      },
      {
        prompt: () => t("Every morning at nine, look at yesterday's numbers and tell me what stands out"),
      },
      {
        prompt: () => t("Rename these files so they sort by date"),
      },
    ],
  },
];

/**
 * Whether an example can be run as things stand.
 *
 * Matched loosely against the configured names, because a connector called
 * `gmail`, `Gmail` or `google-gmail` is the same service to the person who set
 * it up, and being told to connect something already connected is the kind of
 * wrongness that makes a screen untrustworthy.
 */
export function isRunnable(example: ScenarioExample, connected: string[]): boolean {
  if (!example.needs?.length) return true;
  const have = connected.map((name) => name.toLowerCase());
  return example.needs.every((need) =>
    have.some((name) => name.includes(need.toLowerCase()) || need.toLowerCase().includes(name)),
  );
}

/** What is still missing before an example can be run. */
export function missingFor(example: ScenarioExample, connected: string[]): string[] {
  if (!example.needs?.length) return [];
  return example.needs.filter((need) => !isRunnable({ needs: [need], prompt: example.prompt }, connected));
}

/** The scenario with this id, if there is one. */
export function findScenario(id: string): Scenario | undefined {
  return SCENARIOS.find((scenario) => scenario.id === id);
}

/**
 * The kinds of work a service would open up.
 *
 * The Connectors panel lists servers by the name they are configured under,
 * which says what a thing is and not why anyone would want it. Read the other
 * way round — this service unlocks these kinds of work — the same list answers
 * the question someone actually arrived with.
 */
export function scenariosNeeding(connector: string): Scenario[] {
  const wanted = connector.toLowerCase();
  return SCENARIOS.filter((scenario) =>
    scenario.examples.some((example) =>
      example.needs?.some(
        (need) => need.toLowerCase() === wanted || wanted.includes(need.toLowerCase()),
      ),
    ),
  );
}

/** Every service any kind of work asks for, named once. */
export function allNeeds(): string[] {
  const seen = new Set<string>();
  for (const scenario of SCENARIOS) {
    for (const example of scenario.examples) {
      for (const need of example.needs ?? []) seen.add(need);
    }
  }
  return [...seen].sort();
}
