/**
 * Background work, counted as work rather than as executions.
 *
 * Kept out of `App.tsx` so it can be read and tested on its own: the rule it
 * encodes is about what a person means by "a thing running in the background",
 * and that is worth stating once, in one place.
 */

import type { Run } from "./protocol";

/** One piece of background work, however many times it has run. */
export interface RunGroup {
  /** The most recent run, which is what a row describes. */
  latest: Run;
  /** How many runs this stands for. */
  times: number;
}

/**
 * Collapse a scheduled task's repeated runs into the one thing they are.
 *
 * A task set to run every hour files a run every hour, and the landing screen
 * listed each of them: five identical rows reading `5555 · finished`, with
 * "Show more" offering fourteen more of the same. Nineteen executions of one
 * task is one thing that has run nineteen times, and reading it any other way
 * filled a screen whose whole job is to say what is going on.
 *
 * Grouped by the task, not by the title, so two separate dispatches that happen
 * to be named alike stay apart — they are unrelated work, and merging them
 * would hide one behind the other.
 */
export function groupRuns(runs: Run[]): RunGroup[] {
  const groups: RunGroup[] = [];
  const at = new Map<string, RunGroup>();
  for (const run of runs) {
    // A one-off dispatch has no task behind it, so it stands for itself.
    const key = run.taskId ?? run.id;
    const seen = at.get(key);
    if (seen) {
      seen.times += 1;
      // `dispatch/list` answers newest first, but a row claiming to be
      // finished while a later run of the same task was still going would be
      // wrong in the one case this screen exists for.
      if (run.startedAt > seen.latest.startedAt) seen.latest = run;
      continue;
    }
    const group: RunGroup = { latest: run, times: 1 };
    at.set(key, group);
    groups.push(group);
  }
  return groups;
}
