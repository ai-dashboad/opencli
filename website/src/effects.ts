/**
 * The rest of what moves.
 *
 * Four of these read the scroll position or the pointer, and between them they
 * add one scroll listener and one pointer listener to the page. Both are
 * passive, both do nothing but record a number, and all the work happens in a
 * single animation frame that only runs when something has actually changed —
 * a listener per effect would have meant four layout reads per scroll event,
 * which is how a page like this starts to feel heavy on a laptop.
 */

const STILL = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/* ── one frame loop, shared ────────────────────────────────────────────── */

type Job = () => void;

const jobs: Job[] = [];
let queued = false;

function schedule(): void {
  if (queued) return;
  queued = true;
  requestAnimationFrame(() => {
    queued = false;
    for (const job of jobs) job();
  });
}

/* ── the client tilts, and levels off as it is scrolled to ─────────────── */

/**
 * The window starts pitched back and comes upright as it reaches the middle of
 * the screen. It is the one effect here that changes what the hero *is* — a
 * flat panel is a picture of an app, and a panel with depth is a thing sitting
 * in a space.
 */
function tiltOnScroll(): void {
  const shot = document.querySelector<HTMLElement>("[data-app]");
  if (!shot) return;

  const stage = document.createElement("div");
  stage.className = "stage";
  shot.parentNode?.insertBefore(stage, shot);
  stage.append(shot);

  let progress = -1;

  jobs.push(() => {
    const box = stage.getBoundingClientRect();
    const height = window.innerHeight || 1;

    // 0 while the panel is still low on the screen, 1 once its top has come up
    // past a third of the viewport.
    const raw = (height * 0.92 - box.top) / (height * 0.62);
    const next = Math.max(0, Math.min(1, raw));
    if (Math.abs(next - progress) < 0.004) return;
    progress = next;

    const eased = 1 - Math.pow(1 - progress, 3);
    stage.style.setProperty("--tilt", `${(1 - eased) * 15}deg`);
    stage.style.setProperty("--lift", `${(1 - eased) * 44}px`);
    stage.style.setProperty("--shrink", String(0.9 + eased * 0.1));
  });

  schedule();
}

/* ── numbers that count ────────────────────────────────────────────────── */

/**
 * The markup holds the finished numbers. This sets them to zero and counts
 * back up — so a page with no JavaScript, or one under `prefers-reduced-motion`
 * where this never runs, shows four numbers rather than four zeros.
 */
function countUp(): void {
  const cells = document.querySelectorAll<HTMLElement>("[data-count]");
  if (cells.length === 0) return;

  for (const cell of cells) cell.textContent = "0";

  const watcher = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        const cell = entry.target as HTMLElement;
        watcher.unobserve(cell);

        const target = Number(cell.dataset.count ?? "0");
        const span = 1250;
        const from = performance.now();

        const tick = (now: number): void => {
          const through = Math.min(1, (now - from) / span);
          // Fast then settling: a linear count looks like a loading bar.
          const eased = 1 - Math.pow(1 - through, 4);
          cell.textContent = String(Math.round(target * eased));
          if (through < 1) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
      }
    },
    { threshold: 0.5 },
  );

  for (const cell of cells) watcher.observe(cell);
}

/* ── the indexes decode themselves ─────────────────────────────────────── */

const NOISE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/\\<>-_=+*#";

/**
 * Each kicker lands one character at a time, with the characters ahead of the
 * landing point replaced by noise. Spaces are left alone — scrambling those
 * makes the word boundaries jump about and the whole label wobble.
 */
function scramble(): void {
  const labels = document.querySelectorAll<HTMLElement>(".kicker");
  if (labels.length === 0) return;

  const watcher = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        const label = entry.target as HTMLElement;
        watcher.unobserve(label);

        const text = label.textContent ?? "";
        const started = performance.now();
        const span = 90 * text.length;

        const tick = (now: number): void => {
          const through = Math.min(1, (now - started) / span);
          const landed = Math.floor(text.length * through);
          let out = text.slice(0, landed);
          for (let at = landed; at < text.length; at++) {
            out += text[at] === " " ? " " : NOISE[Math.floor(Math.random() * NOISE.length)];
          }
          label.textContent = out;
          if (through < 1) requestAnimationFrame(tick);
          else label.textContent = text;
        };
        requestAnimationFrame(tick);
      }
    },
    { threshold: 1 },
  );

  for (const label of labels) watcher.observe(label);
}

/* ── a light on the page, under the pointer ────────────────────────────── */

function ambient(): void {
  const light = document.createElement("div");
  light.className = "ambient";
  light.setAttribute("aria-hidden", "true");
  document.body.append(light);

  let x = 0;
  let y = 0;
  let moved = false;

  jobs.push(() => {
    if (!moved) return;
    moved = false;
    light.style.setProperty("--x", `${x}px`);
    light.style.setProperty("--y", `${y}px`);
  });

  window.addEventListener(
    "pointermove",
    (event) => {
      x = event.clientX;
      y = event.clientY;
      moved = true;
      light.classList.add("on");
      schedule();
    },
    { passive: true },
  );
}

export function startEffects(): void {
  if (STILL) return;

  tiltOnScroll();
  countUp();
  scramble();
  ambient();

  window.addEventListener("scroll", schedule, { passive: true });
  window.addEventListener("resize", schedule, { passive: true });
}
