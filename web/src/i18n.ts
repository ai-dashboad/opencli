/**
 * The interface, in the reader's language.
 *
 * Keyed by the English sentence rather than by an invented identifier. That
 * choice has consequences worth stating: a missing translation renders the
 * English instead of a broken `settings.model.title`, the source stays
 * readable — `t("Ready when you are")` says what appears on screen — and
 * nobody has to keep a key and its text in agreement. The cost is that
 * changing an English word orphans its translation, which is why
 * `pnpm run i18n:check` lists both the untranslated and the orphaned.
 *
 * `{name}` in a string is filled from the second argument. Numbers and paths
 * are passed that way rather than concatenated, because word order is exactly
 * what differs between languages.
 */

/**
 * An open set, not a closed one.
 *
 * Two languages ship with the product; any number can be added by dropping a
 * file in `$OPENCLI_HOME/locales`. Typing this as a union of the two shipped
 * codes would have made the added ones unrepresentable, which is the wrong way
 * round — the shipped ones are a starting point, not the whole list.
 */
export type Locale = string;

import { zh } from "./locales/zh";

/** What ships in the build. Added languages join these at boot. */
const SHIPPED: { value: Locale; label: string }[] = [
  { value: "en", label: "English" },
  { value: "zh", label: "中文" },
];

let offered: { value: Locale; label: string }[] = [...SHIPPED];

/**
 * The languages on offer, named in themselves.
 *
 * A function rather than a constant because the list is not known until the
 * added ones have been read, and a component that captured the array at import
 * time would show the shipped two forever.
 */
export function locales(): { value: Locale; label: string }[] {
  return offered;
}

const DICTIONARIES: Record<Locale, Record<string, string>> = { en: {}, zh };

/**
 * Take on languages found on disk.
 *
 * Merged rather than assigned, so a file named for a language that already
 * ships corrects individual strings in it instead of replacing the whole
 * dictionary — somebody who dislikes one Chinese sentence should not have to
 * restate the other four hundred to change it.
 */
let directory = "";

/** Where added languages are read from, for telling somebody where to put one. */
export function localeDirectory(): string {
  return directory;
}

export function setLocaleDirectory(path: string): void {
  directory = path;
}

export function addLocales(added: { code: string; name: string; strings: Record<string, string> }[]): void {
  for (const each of added) {
    if (!each.code || !each.strings) continue;
    DICTIONARIES[each.code] = { ...(DICTIONARIES[each.code] ?? {}), ...each.strings };
    const known = offered.find((option) => option.value === each.code);
    if (known) {
      // A shipped language keeps its own name unless the file gives one.
      if (each.name) known.label = each.name;
    } else {
      offered = [...offered, { value: each.code, label: each.name || each.code }];
    }
  }
}

let current: Locale = "en";

/**
 * Which language to start in when nothing has been chosen.
 *
 * The browser's list, in order, so a Chinese-first reader gets Chinese without
 * having to find the setting. Anything unrecognised falls to English, which
 * every string exists in by construction.
 */
export function detectLocale(): Locale {
  const languages = navigator.languages?.length ? navigator.languages : [navigator.language];
  for (const language of languages) {
    const wanted = language?.toLowerCase();
    if (!wanted) continue;
    // `zh-Hans` should find `zh`, and a file named `zh-Hant` should be found
    // by a reader asking for exactly that — so the longest match wins.
    const match = offered
      .filter((option) => wanted.startsWith(option.value.toLowerCase()))
      .sort((a, b) => b.value.length - a.value.length)[0];
    if (match) return match.value;
  }
  return "en";
}

export function setLocale(locale: Locale): void {
  current = locale;
  // The tag the page declares itself in, which decides font selection and
  // hyphenation. `zh` alone leaves a browser to guess between simplified and
  // traditional; the shipped translation is simplified.
  //
  // Choosing the text is this module's job; telling a page about it is a
  // side effect that needs a page. Guarded so the module works without one —
  // it is otherwise pure, and requiring a DOM to ask what a sentence says
  // would be a strange thing to require.
  if (typeof document !== "undefined") {
    document.documentElement.lang = locale === "zh" ? "zh-Hans" : locale;
  }
}

export function getLocale(): Locale {
  return current;
}

/**
 * The text to show.
 *
 * Missing from the dictionary means the English is used, so a half-finished
 * translation is a mix of languages rather than a screen of identifiers.
 */
export function t(text: string, vars?: Record<string, string | number>): string {
  const translated = DICTIONARIES[current]?.[text] ?? text;
  if (!vars) return translated;
  return translated.replace(/\{(\w+)\}/g, (whole, name: string) =>
    name in vars ? String(vars[name]) : whole,
  );
}

/**
 * Choose between two forms by count, in the language being read.
 *
 * Chinese has no plural inflection, so it takes the singular form and lets the
 * number do the work — which is why this is a function rather than a `+ "s"`
 * at each call site.
 */
export function plural(count: number, one: string, many: string): string {
  if (current === "zh") return t(one, { count });
  return t(count === 1 ? one : many, { count });
}
