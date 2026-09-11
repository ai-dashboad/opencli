/**
 * The handoff graph.
 *
 * Bots, duties and the work passed between them already form a graph — the
 * data for it is on disk — and there has never been anywhere to look at it.
 * This is that picture, drawn from the rules the product actually enforces:
 * a chain caps at eight hops, no bot appears in one more than three times, and
 * a bot only takes work from a department allowed to give it any.
 *
 * It is built as SVG rather than canvas because every node here is a label
 * somebody may want to read, and because dragging one means moving an element
 * rather than repainting a scene.
 *
 * On a pointer device the nodes can be dragged. On a touch screen they cannot:
 * dragging a small target with a finger, inside a vertically scrolling page,
 * fights the scroll and usually loses. Touch gets the same graph with the chain
 * playing on its own.
 */

type Bot = {
  id: string;
  label: string;
  team: string;
  /** Fractions of the viewBox, so the layout survives any size. */
  x: number;
  y: number;
};

type Link = { from: string; to: string };

const W = 900;
const H = 380;

const BOTS: Bot[] = [
  { id: "recon", label: "Reconciler", team: "Finance", x: 0.14, y: 0.3 },
  { id: "chase", label: "Chaser", team: "Finance", x: 0.38, y: 0.14 },
  { id: "triage", label: "Triage", team: "Support", x: 0.38, y: 0.62 },
  { id: "answer", label: "Answerer", team: "Support", x: 0.62, y: 0.82 },
  { id: "analyst", label: "Analyst", team: "Research", x: 0.66, y: 0.36 },
  { id: "report", label: "Reporter", team: "Research", x: 0.88, y: 0.6 },
];

const LINKS: Link[] = [
  { from: "recon", to: "chase" },
  { from: "recon", to: "analyst" },
  { from: "triage", to: "answer" },
  { from: "triage", to: "analyst" },
  { from: "analyst", to: "report" },
  { from: "chase", to: "analyst" },
];

/** The chain that plays on its own, in order. */
const CHAIN = ["recon", "chase", "analyst", "report"];

const NS = "http://www.w3.org/2000/svg";

function el<K extends keyof SVGElementTagNameMap>(
  name: K,
  attrs: Record<string, string>,
): SVGElementTagNameMap[K] {
  const node = document.createElementNS(NS, name);
  for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
  return node;
}

export function mountGraph(): void {
  const holder = document.querySelector<HTMLElement>("[data-graph]");
  if (!holder) return;

  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const canDrag = window.matchMedia("(hover: hover) and (pointer: fine)").matches;

  const at = new Map(BOTS.map((bot) => [bot.id, { x: bot.x * W, y: bot.y * H }]));

  const svg = el("svg", {
    viewBox: `0 0 ${W} ${H}`,
    class: "graph",
    role: "img",
    "aria-label":
      "Six bots across three departments, with arrows showing which of them may hand work to which.",
  });

  const edgeLayer = el("g", { class: "edges" });
  const nodeLayer = el("g", { class: "nodes" });
  svg.append(edgeLayer, nodeLayer);

  const paths = new Map<string, SVGPathElement>();
  const pulses = new Map<string, SVGCircleElement>();

  for (const link of LINKS) {
    const key = `${link.from}>${link.to}`;
    const path = el("path", { class: "edge", d: "" });
    // Parked off-frame *and* transparent: the SVG does not clip, and under
    // `prefers-reduced-motion` nothing ever runs to set the opacity, so a
    // visible dot would simply sit outside the graph forever.
    const pulse = el("circle", {
      class: "pulse",
      r: "3.4",
      cx: "-99",
      cy: "-99",
      opacity: "0",
    });
    paths.set(key, path);
    pulses.set(key, pulse);
    edgeLayer.append(path, pulse);
  }

  const groups = new Map<string, SVGGElement>();

  for (const bot of BOTS) {
    const group = el("g", { class: "node", "data-id": bot.id, tabindex: "0" });
    const halo = el("circle", { class: "halo", r: "30", cx: "0", cy: "0" });
    const disc = el("circle", { class: "disc", r: "19", cx: "0", cy: "0" });
    const name = el("text", { class: "name", x: "0", y: "40" });
    name.textContent = bot.label;
    const team = el("text", { class: "team", x: "0", y: "55" });
    team.textContent = bot.team;
    group.append(halo, disc, name, team);
    nodeLayer.append(group);
    groups.set(bot.id, group);
  }

  /** A curve between two discs, stopping short of each so the ends stay clear. */
  function draw(): void {
    for (const link of LINKS) {
      const from = at.get(link.from);
      const to = at.get(link.to);
      const path = paths.get(`${link.from}>${link.to}`);
      if (!from || !to || !path) continue;

      const dx = to.x - from.x;
      const dy = to.y - from.y;
      const length = Math.hypot(dx, dy) || 1;
      const gap = 24;
      const sx = from.x + (dx / length) * gap;
      const sy = from.y + (dy / length) * gap;
      const ex = to.x - (dx / length) * gap;
      const ey = to.y - (dy / length) * gap;

      // Bowed away from the straight line, so two bots with links in both
      // directions do not draw one path on top of another.
      const bow = 0.18;
      const cx = (sx + ex) / 2 - dy * bow;
      const cy = (sy + ey) / 2 + dx * bow;

      path.setAttribute("d", `M${sx} ${sy} Q${cx} ${cy} ${ex} ${ey}`);
    }

    for (const [id, group] of groups) {
      const point = at.get(id);
      if (point) group.setAttribute("transform", `translate(${point.x} ${point.y})`);
    }
  }

  draw();
  holder.prepend(svg);

  // ── hovering a bot lights the chain it can reach ───────────────────────────
  function highlight(id: string | null): void {
    const reached = new Set<string>();
    if (id) {
      const queue = [id];
      // Eight, because that is where the product stops.
      for (let hop = 0; hop < 8 && queue.length; hop++) {
        const next: string[] = [];
        for (const here of queue) {
          reached.add(here);
          for (const link of LINKS) {
            if (link.from === here && !reached.has(link.to)) next.push(link.to);
          }
        }
        queue.length = 0;
        queue.push(...next);
      }
    }
    svg.classList.toggle("focused", id !== null);
    for (const [botId, group] of groups) group.classList.toggle("lit", reached.has(botId));
    for (const link of LINKS) {
      const path = paths.get(`${link.from}>${link.to}`);
      path?.classList.toggle("lit", reached.has(link.from) && reached.has(link.to));
    }
  }

  for (const [id, group] of groups) {
    group.addEventListener("pointerenter", () => highlight(id));
    group.addEventListener("focus", () => highlight(id));
    group.addEventListener("blur", () => highlight(null));
  }
  svg.addEventListener("pointerleave", () => highlight(null));

  // ── dragging, where dragging makes sense ───────────────────────────────────
  if (canDrag) {
    holder.classList.add("draggable");
    let held: string | null = null;

    function toViewBox(event: PointerEvent): { x: number; y: number } {
      const box = svg.getBoundingClientRect();
      return {
        x: ((event.clientX - box.left) / box.width) * W,
        y: ((event.clientY - box.top) / box.height) * H,
      };
    }

    svg.addEventListener("pointerdown", (event) => {
      const group = (event.target as Element).closest<SVGGElement>(".node");
      if (!group) return;
      held = group.getAttribute("data-id");
      group.classList.add("held");
      svg.setPointerCapture(event.pointerId);
      event.preventDefault();
    });

    svg.addEventListener("pointermove", (event) => {
      if (!held) return;
      const point = toViewBox(event);
      // Kept inside the frame, with room for the labels under each disc.
      at.set(held, {
        x: Math.max(34, Math.min(W - 34, point.x)),
        y: Math.max(26, Math.min(H - 62, point.y)),
      });
      draw();
    });

    const release = (event: PointerEvent): void => {
      if (!held) return;
      groups.get(held)?.classList.remove("held");
      held = null;
      if (svg.hasPointerCapture(event.pointerId)) svg.releasePointerCapture(event.pointerId);
    };
    svg.addEventListener("pointerup", release);
    svg.addEventListener("pointercancel", release);
  }

  // ── the chain, travelling ──────────────────────────────────────────────────
  if (still) return;

  let leg = 0;
  let started = 0;
  let frame = 0;
  const LEG_MS = 1150;

  function step(now: number): void {
    frame = requestAnimationFrame(step);
    if (!started) started = now;

    const through = Math.min(1, (now - started) / LEG_MS);
    const from = CHAIN[leg];
    const to = CHAIN[(leg + 1) % CHAIN.length];
    const path = paths.get(`${from}>${to}`);

    for (const pulse of pulses.values()) pulse.setAttribute("opacity", "0");

    const pulse = pulses.get(`${from}>${to}`);
    if (path && pulse) {
      const total = path.getTotalLength();
      const point = path.getPointAtLength(total * through);
      pulse.setAttribute("cx", String(point.x));
      pulse.setAttribute("cy", String(point.y));
      // Faded at both ends, so it arrives and leaves rather than blinking.
      pulse.setAttribute("opacity", String(Math.sin(through * Math.PI)));
    }

    groups.get(from)?.classList.toggle("sending", through < 0.5);
    groups.get(to)?.classList.toggle("sending", through >= 0.5);

    if (through === 1) {
      groups.get(from)?.classList.remove("sending");
      leg = (leg + 1) % (CHAIN.length - 1);
      started = now;
    }
  }

  const watcher = new IntersectionObserver((entries) => {
    const near = entries.some((entry) => entry.isIntersecting);
    if (near && !frame) {
      started = 0;
      frame = requestAnimationFrame(step);
    } else if (!near && frame) {
      cancelAnimationFrame(frame);
      frame = 0;
    }
  });
  watcher.observe(holder);
}
