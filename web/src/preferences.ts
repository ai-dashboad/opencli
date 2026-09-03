/**
 * Preferences that belong to the person, not to the agent.
 *
 * Tone, effort, whether thinking is shown, which palette — none of these are
 * facts about a machine or a model, so they are not written into
 * `config.toml`. They are kept in this browser (or this app's web view), which
 * also means the browser build and the desktop build each remember their own,
 * which is right: they are used on different screens.
 *
 * Kept out of `App.tsx` because two of them have to be applied to the document
 * as well as remembered, and that pairing is easy to forget when a setting is
 * added.
 */

import type { Preferences } from "./protocol";
import { detectLocale, setLocale } from "./i18n";

const STORE_KEY = "opencli.preferences";

/** What someone gets before they have chosen anything. */
export const DEFAULT_PREFERENCES: Preferences = {
  approvalPolicy: "untrusted",
  appearance: "system",
  textSize: "normal",
  language: "system",
};

export function readPreferences(): Preferences {
  try {
    const raw = window.localStorage.getItem(STORE_KEY);
    if (!raw) return DEFAULT_PREFERENCES;
    // Merged over the defaults rather than trusted whole: a preference added
    // in a later version is missing from what an earlier one wrote down.
    return { ...DEFAULT_PREFERENCES, ...(JSON.parse(raw) as Preferences) };
  } catch {
    // Private browsing, a corrupt value, a disabled store — none of which is
    // worth failing to start over.
    return DEFAULT_PREFERENCES;
  }
}

export function writePreferences(preferences: Preferences): void {
  try {
    window.localStorage.setItem(STORE_KEY, JSON.stringify(preferences));
  } catch {
    // As above: the app works, it just forgets.
  }
}

/**
 * Put the visual preferences and the language on the document.
 *
 * `system` removes the attribute rather than setting it, so the media query in
 * the stylesheet is what decides — one place makes the choice instead of two.
 */
export function applyAppearance(preferences: Preferences): void {
  const root = document.documentElement;
  const appearance = preferences.appearance ?? "system";
  if (appearance === "system") {
    root.removeAttribute("data-theme");
  } else {
    root.setAttribute("data-theme", appearance);
  }

  const size = preferences.textSize ?? "normal";
  if (size === "normal") {
    root.removeAttribute("data-text");
  } else {
    root.setAttribute("data-text", size);
  }

  const language = preferences.language ?? "system";
  setLocale(language === "system" ? detectLocale() : language);
}
