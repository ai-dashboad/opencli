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
 *
 * Dictionaries are fetched when a language is chosen, not when the app starts.
 * With two of them, bundling both cost nothing. With ten, it would nearly
 * double a 384kB bundle so that every reader could carry nine translations
 * they will never see.
 */

/**
 * An open set, not a closed one.
 *
 * Ten languages ship with the product; any number can be added by dropping a
 * file in `$OPENCLI_HOME/locales`. Typing this as a union of the shipped codes
 * would have made the added ones unrepresentable, which is the wrong way round
 * — the shipped ones are a starting point, not the whole list.
 */
export type Locale = string;

type Loader = () => Promise<Record<string, string>>;

/**
 * What ships in the build, each named in itself.
 *
 * Named in itself, untranslated, so somebody who cannot read the language
 * currently on screen can still find their own. A reader looking for Korean is
 * looking for 한국어, not for whatever English calls it.
 */
const SHIPPED: { value: Locale; label: string; load: Loader }[] = [
  { value: "en", label: "English", load: async () => ({}) },
  { value: "zh", label: "简体中文", load: () => strings("zh") },
  { value: "zh-Hant", label: "繁體中文", load: () => strings("zh-Hant") },
  { value: "ja", label: "日本語", load: () => strings("ja") },
  { value: "ko", label: "한국어", load: () => strings("ko") },
  { value: "es", label: "Español", load: () => strings("es") },
  { value: "pt-BR", label: "Português (Brasil)", load: () => strings("pt-BR") },
  { value: "fr", label: "Français", load: () => strings("fr") },
  { value: "de", label: "Deutsch", load: () => strings("de") },
  { value: "ru", label: "Русский", load: () => strings("ru") },
];

/**
 * One shipped dictionary, as its own chunk.
 *
 * The same shape as a file somebody adds in `$OPENCLI_HOME/locales`: an
 * envelope with a `name` and the sentences under `strings`. One format for
 * both means a shipped translation can be copied out, corrected, and put back
 * without anything in between.
 */
async function strings(code: Locale): Promise<Record<string, string>> {
  const loaded = (await import(`./locales/${code}.json`)) as {
    default: { strings: Record<string, string> };
  };
  return loaded.default.strings;
}

let offered: { value: Locale; label: string }[] = SHIPPED.map(({ value, label }) => ({
  value,
  label,
}));

/**
 * The languages on offer, named in themselves.
 *
 * A function rather than a constant because the list is not known until the
 * added ones have been read, and a component that captured the array at import
 * time would show the shipped ones forever.
 */
export function locales(): { value: Locale; label: string }[] {
  return offered;
}

const DICTIONARIES: Record<Locale, Record<string, string>> = { en: {} };

/** Which shipped dictionaries have been asked for, so none is fetched twice. */
const requested = new Set<Locale>(["en"]);

/**
 * Bumped when a dictionary arrives.
 *
 * `t()` is synchronous and called from hundreds of places, so a language is
 * switched at once and its words arrive a moment later. Without this the tree
 * would keep the English it was drawn with: the locale it is keyed on did not
 * change, only what that locale knows.
 */
let revision = 0;

/** What is being read, and how much of it has arrived. Changes on both. */
export function localeTag(): string {
  return `${current}#${revision}`;
}

async function load(locale: Locale): Promise<void> {
  if (requested.has(locale)) return;
  const shipped = SHIPPED.find((each) => each.value === locale);
  // A language added on disk is already here in full; there is nothing to
  // fetch, and looking would be a request for a chunk that was never built.
  if (!shipped) return;
  requested.add(locale);
  try {
    const strings = await shipped.load();
    // Underneath, not over: a file in `$OPENCLI_HOME/locales` correcting a
    // shipped sentence must win whichever of the two arrived first.
    DICTIONARIES[locale] = { ...strings, ...(DICTIONARIES[locale] ?? {}) };
    revision += 1;
  } catch {
    // The chunk did not load. English is what every string falls back to, so
    // the interface stays readable; asking again later is worth allowing.
    requested.delete(locale);
  }
}

let directory = "";

/** Where added languages are read from, for telling somebody where to put one. */
export function localeDirectory(): string {
  return directory;
}

export function setLocaleDirectory(path: string): void {
  directory = path;
}

/**
 * Take on languages found on disk.
 *
 * Merged rather than assigned, so a file named for a language that already
 * ships corrects individual strings in it instead of replacing the whole
 * dictionary — somebody who dislikes one Chinese sentence should not have to
 * restate the other four hundred to change it.
 */
export function addLocales(
  added: { code: string; name: string; strings: Record<string, string> }[],
): void {
  for (const each of added) {
    if (!each.code || !each.strings) continue;
    DICTIONARIES[each.code] = { ...(DICTIONARIES[each.code] ?? {}), ...each.strings };
    revision += 1;
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
    // Longest match wins, so `zh-Hant-TW` finds `zh-Hant` rather than `zh`.
    // The other order would give a traditional-Chinese reader the simplified
    // translation, which is worse than giving them English: it looks right.
    const match = offered
      .filter((option) => wanted.startsWith(option.value.toLowerCase()))
      .sort((a, b) => b.value.length - a.value.length)[0];
    if (match) return match.value;
  }
  return "en";
}

/**
 * The subtag the page declares itself in, which decides font selection.
 *
 * A browser given `zh` guesses between simplified and traditional, and on a
 * Japanese system it guesses wrong — the same code points are drawn with
 * different glyphs, and a reader sees a page set in the wrong script. Both
 * Chinese translations therefore say which they are.
 */
function pageTag(locale: Locale): string {
  if (locale === "zh") return "zh-Hans";
  return locale;
}

export function setLocale(locale: Locale): Promise<void> {
  current = locale;
  // Choosing the text is this module's job; telling a page about it is a side
  // effect that needs a page. Guarded so the module works without one — it is
  // otherwise pure, and requiring a DOM to ask what a sentence says would be a
  // strange thing to require.
  if (typeof document !== "undefined") {
    document.documentElement.lang = pageTag(locale);
  }
  // Returned rather than fired and forgotten: whoever changed the language is
  // the one that has to redraw once its words are here.
  return load(locale);
}

export function getLocale(): Locale {
  return current;
}

/**
 * The text to show.
 *
 * Missing from the dictionary means the English is used, so a half-finished
 * translation is a mix of languages rather than a screen of identifiers. That
 * is also what is on screen for the moment between choosing a language and its
 * dictionary arriving.
 */
export function t(text: string, vars?: Record<string, string | number>): string {
  const translated = DICTIONARIES[current]?.[text] ?? text;
  if (!vars) return translated;
  return translated.replace(/\{(\w+)\}/g, (whole, name: string) =>
    name in vars ? String(vars[name]) : whole,
  );
}

/**
 * Languages where one form serves every count.
 *
 * Not a shortcut: Chinese, Japanese and Korean do not inflect a noun for
 * number at all, so `1 个文件` and `9 个文件` differ only in the digit.
 */
const UNCOUNTED = new Set(["zh", "zh-Hant", "ja", "ko"]);

/**
 * Choose between two forms by count, in the language being read.
 *
 * Two forms is what this API offers, which is enough for English, German,
 * Spanish, French and Portuguese and is *not* enough for Russian — it wants a
 * third for 2–4. Rather than pretend otherwise, the Russian translations of
 * these few strings are written so the number carries the sense on its own.
 */
export function plural(count: number, one: string, many: string): string {
  if (UNCOUNTED.has(current)) return t(one, { count });
  return t(count === 1 ? one : many, { count });
}
