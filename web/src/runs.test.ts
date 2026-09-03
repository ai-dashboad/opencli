import { describe, expect, it } from "vitest";

import { groupRuns } from "./runs";
import type { Run } from "./protocol";

function run(over: Partial<Run> & Pick<Run, "id">): Run {
  return {
    title: "5555",
    prompt: "5555",
    cwd: "/Users/cw/Projects/555",
    model: null,
    source: "scheduled",
    status: "done",
    startedAt: 0,
    finishedAt: 1,
    output: "",
    exitCode: 0,
    taskId: "task-1788367619-6fcdaf",
    ...over,
  };
}

describe("groupRuns", () => {
  it("should show a scheduled task once however many times it has run", () => {
    // The screen that prompted this: nineteen finished runs of one hourly
    // task, listed five at a time with "Show more" for the rest.
    const runs = Array.from({ length: 19 }, (_, at) =>
      run({ id: `run-${at}`, startedAt: 1_000 - at }),
    );

    const groups = groupRuns(runs);

    expect(groups).toHaveLength(1);
    expect(groups[0].times).toBe(19);
  });

  it("should describe the group by its most recent run", () => {
    const groups = groupRuns([
      run({ id: "older", startedAt: 100, status: "done" }),
      run({ id: "newest", startedAt: 900, status: "running" }),
    ]);

    expect(groups[0].latest.id).toBe("newest");
    expect(groups[0].latest.status).toBe("running");
  });

  it("should keep separate tasks separate when they share a title", () => {
    const groups = groupRuns([
      run({ id: "a", taskId: "task-one" }),
      run({ id: "b", taskId: "task-two" }),
    ]);

    expect(groups).toHaveLength(2);
  });

  it("should let a one-off dispatch stand for itself", () => {
    // No task behind it, so nothing to group by but the run.
    const groups = groupRuns([
      run({ id: "a", source: "dispatch", taskId: null }),
      run({ id: "b", source: "dispatch", taskId: null }),
    ]);

    expect(groups).toHaveLength(2);
  });

  it("should keep the order it was given", () => {
    const groups = groupRuns([
      run({ id: "a", taskId: "second", startedAt: 900 }),
      run({ id: "b", taskId: "first", startedAt: 100 }),
    ]);

    expect(groups.map((group) => group.latest.taskId)).toEqual(["second", "first"]);
  });
});
