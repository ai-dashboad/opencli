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

export type Locale = "en" | "zh";

/** The languages on offer, named in themselves. */
export const LOCALES: { value: Locale; label: string }[] = [
  { value: "en", label: "English" },
  { value: "zh", label: "中文" },
];

import { zh } from "./locales/zh";

const DICTIONARIES: Record<Locale, Record<string, string>> = { en: {}, zh };

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
    if (language?.toLowerCase().startsWith("zh")) return "zh";
    if (language?.toLowerCase().startsWith("en")) return "en";
  }
  return "en";
}

export function setLocale(locale: Locale): void {
  current = locale;
  document.documentElement.lang = locale === "zh" ? "zh-Hans" : "en";
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
  const translated = DICTIONARIES[current][text] ?? text;
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
