/**
 * What the desktop app shows while the agent starts.
 *
 * It used to be the word "OpenCLI" and a sentence. Starting takes about a
 * second — long enough that a still screen reads as a stall — so the mark
 * draws itself in the time that is actually being waited on.
 *
 * The line underneath is deliberately **not** a progress bar. Nothing here
 * knows how far along the agent is, and a bar that fills at a made-up rate is
 * a lie told smoothly. It sweeps to say work is happening, and stops in place
 * when it fails.
 */

import { OpenCliMark } from "./icons";

export function Boot({ failed, detail }: { failed: boolean; detail?: string | null }) {
  return (
    <main className={`boot${failed ? " failed" : ""}`}>
      <div className="boot-mark" aria-hidden="true">
        <svg width="72" height="72" viewBox="0 0 32 32" fill="none">
          {/*
           * Drawn rather than shown: the two strokes of the mark trace
           * themselves in, the chevron first and the cursor after it, which is
           * the order a person would draw them.
           */}
          <polyline
            className="boot-stroke chevron"
            points="17,9 9,16 17,23"
            stroke="currentColor"
            strokeWidth="2.6"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <line
            className="boot-stroke cursor"
            x1="17"
            y1="23"
            x2="25"
            y2="23"
            stroke="currentColor"
            strokeWidth="2.6"
            strokeLinecap="round"
          />
        </svg>
      </div>

      <h1 className="boot-word">OpenCLI</h1>
      <p className="boot-note">
        {failed ? "The agent could not be started." : "Starting the agent…"}
      </p>
      <div className="boot-line" role="presentation">
        <span />
      </div>
      {failed && detail ? <p className="boot-detail">{detail}</p> : null}
    </main>
  );
}

/** Re-exported so the landing screen and the boot screen cannot drift apart. */
export { OpenCliMark };
