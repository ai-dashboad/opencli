/**
 * When Enter in the composer means "send".
 *
 * Its own function because the decision is where the bug was: Enter was
 * treated as send while an input method was composing, which swallowed the
 * keypress that confirms a candidate and made Chinese, Japanese and Korean
 * input impossible.
 */
export function shouldSend(event: {
  key: string;
  shiftKey: boolean;
  isComposing: boolean;
}): boolean {
  if (event.isComposing) return false;
  return event.key === "Enter" && !event.shiftKey;
}

/**
 * Whether a key should dismiss a search box.
 *
 * Escape cancels an input method's candidate list, so closing the search on it
 * would discard what was half-typed.
 */
export function shouldDismiss(event: { key: string; isComposing: boolean }): boolean {
  return !event.isComposing && event.key === "Escape";
}
