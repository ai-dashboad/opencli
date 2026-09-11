/**
 * The things on this page that move.
 *
 * All three are enhancements over markup that is already complete and already
 * readable: the terminal holds its finished transcript, the sections are
 * visible, the cells are lit well enough to read. Nothing here is load-bearing,
 * so nothing here is awaited and every piece checks for its own absence.
 *
 * Under `prefers-reduced-motion` the whole module turns itself off and the page
 * is exactly the page without it.
 */

const STILL = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/**
 * Sections arrive as they are scrolled to.
 *
 * The class goes on and stays on — `unobserve` after the first crossing, so
 * scrolling back up does not replay anything. A page that re-animates on every
 * pass is a page nobody can read twice.
 */
function revealOnScroll(): void {
  const targets = document.querySelectorAll<HTMLElement>("[data-reveal]");
  if (targets.length === 0) return;

  const watcher = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("shown");
        watcher.unobserve(entry.target);
      }
    },
    { rootMargin: "0px 0px -12% 0px", threshold: 0.08 },
  );

  for (const target of targets) {
    target.classList.add("armed");
    watcher.observe(target);
  }
}

/**
 * A light that follows the pointer across the lattice.
 *
 * One listener on each grid rather than one per cell, and the only thing it
 * writes is two custom properties on the cell under the cursor — the gradient
 * itself is in the stylesheet, so this never touches layout and never reads it
 * back except through `getBoundingClientRect` on the cell already being
 * entered.
 */
function spotlight(): void {
  for (const lattice of document.querySelectorAll<HTMLElement>(".lattice")) {
    lattice.addEventListener(
      "pointermove",
      (event) => {
        const cell = (event.target as HTMLElement).closest<HTMLElement>(".cell");
        if (!cell) return;
        const box = cell.getBoundingClientRect();
        cell.style.setProperty("--mx", `${event.clientX - box.left}px`);
        cell.style.setProperty("--my", `${event.clientY - box.top}px`);
      },
      { passive: true },
    );
  }
}

/** Characters per second for the command line, and the gap between outputs. */
const TYPE_MS = 26;
const LINE_MS = 190;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * The hero's terminal runs its session.
 *
 * The transcript is in the HTML in full. This takes it away and gives it back
 * at the speed it would have happened at, which for a command-line tool is the
 * one piece of motion on the page that is also the product.
 *
 * It waits to be looked at first: a terminal that finished typing before the
 * visitor arrived has only ever shown them a static picture.
 */
function typeTerminal(): void {
  const found = document.querySelector<HTMLElement>("[data-terminal]");
  if (!found) return;

  const typedOrNull = found.querySelector<HTMLElement>("[data-type]");
  const lines = [...found.querySelectorAll<HTMLElement>("[data-line]")];
  if (!typedOrNull || lines.length === 0) return;

  // Re-bound past the guards: `run` is hoisted, so the narrowing above does not
  // reach inside it.
  const terminal = found;
  const typed = typedOrNull;
  const command = typed.textContent ?? "";

  async function run(): Promise<void> {
    terminal.classList.add("running");
    typed.textContent = "";
    for (const line of lines) line.classList.remove("out");

    for (let at = 1; at <= command.length; at++) {
      typed.textContent = command.slice(0, at);
      await sleep(TYPE_MS);
    }

    await sleep(360);
    terminal.classList.remove("running");

    for (const line of lines) {
      line.classList.add("out");
      await sleep(LINE_MS);
    }
  }

  // Hide the finished transcript only now that it is certain something is going
  // to put it back.
  terminal.classList.add("live");

  const watcher = new IntersectionObserver(
    (entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;
      watcher.disconnect();
      void run();
    },
    { threshold: 0.25 },
  );
  watcher.observe(terminal);
}


/**
 * The desktop client plays its exchange.
 *
 * The pauses are not uniform, because the thing being shown is not uniform:
 * reading a file is quick, deciding to ask is not, and the approval card has
 * to sit there long enough to be read before it is answered. A constant
 * interval would show the same six boxes arriving on a metronome, which is the
 * one impression the product does not want to give.
 */
const BEATS: Record<string, number> = {
  ask: 900,
  think: 1100,
  tool: 620,
  approval: 1700,
  found: 900,
  files: 700,
};

function playApp(): void {
  const found = document.querySelector<HTMLElement>("[data-app]");
  if (!found) return;

  const steps = [...found.querySelectorAll<HTMLElement>(".step")];
  if (steps.length === 0) return;

  const app = found;

  function beat(step: HTMLElement): number {
    for (const kind of Object.keys(BEATS)) {
      if (step.classList.contains(kind)) return BEATS[kind];
    }
    return 600;
  }

  async function run(): Promise<void> {
    const thinking = steps.find((step) => step.classList.contains("think"));
    let toolsSeen = 0;

    for (const step of steps) {
      step.classList.add("out");

      // The dots stand down as soon as there is something to show for them.
      if (step.classList.contains("tool") && ++toolsSeen === 1 && thinking) {
        thinking.classList.add("gone");
      }

      // Approve is pressed a moment after the card has had time to be read.
      if (step.classList.contains("approval")) {
        await sleep(beat(step));
        app.classList.add("approved");
        await sleep(520);
        continue;
      }

      await sleep(beat(step));
    }
  }

  app.classList.add("live");

  const watcher = new IntersectionObserver(
    (entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;
      watcher.disconnect();
      void run();
    },
    { threshold: 0.2 },
  );
  watcher.observe(app);
}

export function startMotion(): void {
  if (STILL) return;
  revealOnScroll();
  spotlight();
  playApp();
  typeTerminal();
}
