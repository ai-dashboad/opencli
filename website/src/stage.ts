/**
 * The arrival, the scroll, and the strip of metal between sections.
 *
 * Three things that change how the whole page feels rather than how one part
 * of it looks. All three are off entirely under `prefers-reduced-motion`, and
 * all three are written so that failing to run leaves the ordinary page.
 */

const STILL = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/* ── the arrival ───────────────────────────────────────────────────────── */

/**
 * A short curtain over the first paint, then the hero wipes in.
 *
 * The rule it follows is that it must never be the reason somebody waits. It
 * is capped at 620ms whatever happens, it lifts the moment the hero's first
 * frame exists, and — the part that matters — the page underneath is fully
 * built and fully scrollable the entire time. Anyone who reloads into it and
 * immediately scrolls goes straight past it.
 */
function curtain(): void {
  const hero = document.querySelector<HTMLElement>(".hero");
  if (!hero) return;

  const veil = document.createElement("div");
  veil.className = "curtain";
  veil.setAttribute("aria-hidden", "true");
  veil.innerHTML = '<span class="bar"><i></i></span>';

  let done = false;
  const lift = (): void => {
    if (done) return;
    done = true;
    document.documentElement.classList.remove("arriving");
    document.documentElement.classList.add("arrived");
    veil.classList.add("gone");
    setTimeout(() => veil.remove(), 900);
  };

  /*
   * The class that hides the hero's words and the timer that puts them back go
   * on in the same breath, before anything else can throw. `arriving` sets
   * opacity to zero; if something failed between adding it and arranging its
   * removal, the hero would have no text in it and no way to get any.
   */
  document.documentElement.classList.add("arriving");
  const cap = setTimeout(lift, 620);

  document.body.append(veil);

  // Or sooner, if the shader has something to show before the cap runs out.
  const watcher = new MutationObserver(() => {
    if (!hero.classList.contains("has-shader")) return;
    watcher.disconnect();
    clearTimeout(cap);
    setTimeout(lift, 260);
  });
  watcher.observe(hero, { attributes: true, attributeFilter: ["class"] });
}

/* ── the scroll ────────────────────────────────────────────────────────── */

/**
 * Scrolling, eased.
 *
 * The page is translated towards the real scroll position rather than sitting
 * on it, which is most of what separates the feel of the sites this was
 * modelled on from an ordinary one.
 *
 * The rules it keeps, because this is the effect that most often ruins a page:
 *
 *   - The document keeps its real height and the browser keeps doing the
 *     scrolling. Nothing here intercepts the wheel, so momentum, trackpads,
 *     page keys, find-in-page and the scrollbar all behave exactly as they did.
 *   - It is skipped entirely on touch, where the platform's own scrolling is
 *     better than anything this could do and fighting it feels broken.
 *   - It stops running the moment the two positions agree, so a still page
 *     costs nothing.
 */
function easedScroll(): void {
  const fine = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  if (!fine) return;

  const main = document.querySelector<HTMLElement>("main");
  const footer = document.querySelector<HTMLElement>("footer");
  if (!main || !footer) return;

  // Everything that scrolls moves as one piece. Translating `main` alone would
  // have left the footer sitting at the real scroll position while the content
  // above it lagged, which opens and closes a gap between them on every flick.
  // The header stays outside: it is sticky, and sticky inside a transformed
  // element stops being sticky.
  const shell = document.createElement("div");
  shell.className = "scroller";
  main.parentNode?.insertBefore(shell, main);
  shell.append(main, footer);

  let shown = window.scrollY;
  let frame = 0;

  function step(): void {
    const real = window.scrollY;
    shown += (real - shown) * 0.11;

    if (Math.abs(real - shown) < 0.08) {
      shown = real;
      shell.style.transform = "";
      frame = 0;
      return;
    }

    shell.style.transform = `translate3d(0, ${(real - shown).toFixed(2)}px, 0)`;
    frame = requestAnimationFrame(step);
  }

  window.addEventListener(
    "scroll",
    () => {
      if (!frame) frame = requestAnimationFrame(step);
    },
    { passive: true },
  );
}

/* ── the strip of metal ────────────────────────────────────────────────── */

const BAND_VERTEX = `
attribute vec2 position;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
}
`;

/*
 * The same material as the mark, poured flat and run across the page. It is a
 * height field rather than a solid — no marching, just a surface whose normal
 * is known analytically — so it costs a fraction of what the hero does and can
 * sit at full width without being felt.
 */
const BAND_FRAGMENT = `
precision mediump float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uSlide;

vec3 studio(vec3 rd) {
  float up = rd.y * 0.5 + 0.5;

  // A hard horizon rather than a gradient. Polished metal is read from the
  // *edges* in what it reflects — a smooth environment reflects as smooth
  // blobs no matter how much resolution it is given, which is what the first
  // two attempts at this band looked like.
  vec3 col = mix(vec3(0.012, 0.012, 0.014), vec3(0.30, 0.31, 0.34),
                 smoothstep(0.46, 0.54, up));

  // Three narrow strips. Narrow is the whole point: they sweep across the
  // surface as thin bright streaks instead of pooling.
  float a = smoothstep(0.035, 0.0, abs(rd.y - 0.46));
  col += vec3(1.0, 1.0, 1.0) * a * 5.0;

  float b = smoothstep(0.022, 0.0, abs(rd.y - 0.2));
  col += vec3(0.92, 0.95, 1.0) * b * 3.2;

  float c = smoothstep(0.03, 0.0, abs(rd.y + 0.26));
  col += vec3(0.98, 0.58, 0.36) * c * 2.4;

  return col;
}

void main() {
  vec2 uv = gl_FragCoord.xy / uResolution.xy;
  float aspect = uResolution.x / uResolution.y;

  vec2 p = vec2(uv.x * aspect, uv.y);
  p.x += uSlide;

  float t = uTime * 0.3;

  /*
   * Crossing waves, and the normal is their slope — there is no surface here,
   * only the direction one would face. The y terms carry as much weight as the
   * x terms on purpose: with x alone the reflection came out as vertical
   * stripes, which reads as a venetian blind rather than as poured metal.
   */
  float dx =
      cos(p.x * 4.1 + p.y * 2.2 + t) * 4.1 * 0.42 +
      cos(p.x * 7.9 - p.y * 5.1 - t * 1.2) * 7.9 * 0.24 +
      cos(p.x * 14.0 + p.y * 9.0 + t * 0.6) * 14.0 * 0.09;

  float dy =
      cos(p.x * 4.1 + p.y * 2.2 + t) * 2.2 * 0.42 -
      cos(p.x * 7.9 - p.y * 5.1 - t * 1.2) * 5.1 * 0.24 +
      cos(p.x * 14.0 + p.y * 9.0 + t * 0.6) * 9.0 * 0.09;

  vec3 n = normalize(vec3(-dx * 0.10, -dy * 0.10, 1.0));
  vec3 view = vec3(0.0, 0.0, 1.0);
  vec3 metal = studio(reflect(-view, n));

  float fres = pow(1.0 - max(n.z, 0.0), 3.0);
  metal += vec3(0.98, 0.62, 0.44) * fres * 0.3;

  // Well under the page it sits in. It is a ribbon passing through, and the
  // sections on either side are the reason anyone is here.
  metal *= 0.62;

  float edge = smoothstep(0.0, 0.34, uv.y) * smoothstep(1.0, 0.66, uv.y);
  edge *= edge;

  gl_FragColor = vec4(metal * edge, 1.0);
}
`;

function makeProgram(gl: WebGLRenderingContext, fragment: string): WebGLProgram | null {
  const build = (type: number, source: string): WebGLShader | null => {
    const shader = gl.createShader(type);
    if (!shader) return null;
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      gl.deleteShader(shader);
      return null;
    }
    return shader;
  };

  const vertex = build(gl.VERTEX_SHADER, BAND_VERTEX);
  const frag = build(gl.FRAGMENT_SHADER, fragment);
  if (!vertex || !frag) return null;

  const program = gl.createProgram();
  if (!program) return null;
  gl.attachShader(program, vertex);
  gl.attachShader(program, frag);
  gl.linkProgram(program);
  gl.deleteShader(vertex);
  gl.deleteShader(frag);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    gl.deleteProgram(program);
    return null;
  }
  return program;
}

function metalBand(): void {
  const found = document.querySelector<HTMLElement>("[data-band]");
  if (!found) return;

  // Re-bound past the guard, so the hoisted functions below see it as present.
  const holder = found;

  const canvas = document.createElement("canvas");
  canvas.setAttribute("aria-hidden", "true");

  const context = canvas.getContext("webgl", {
    alpha: false,
    antialias: false,
    depth: false,
    stencil: false,
    powerPreference: "low-power",
  }) as WebGLRenderingContext | null;
  if (!context) return;

  const gl = context;
  const program = makeProgram(gl, BAND_FRAGMENT);
  if (!program) return;

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  const position = gl.getAttribLocation(program, "position");
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

  gl.useProgram(program);
  const uResolution = gl.getUniformLocation(program, "uResolution");
  const uTime = gl.getUniformLocation(program, "uTime");
  const uSlide = gl.getUniformLocation(program, "uSlide");

  let frame = 0;
  let onScreen = false;

  function resize(): void {
    // Near enough full resolution. This is a height field with an analytic
    // normal — no marching — so it costs a fraction of the hero and there is
    // no reason to blur a reflection that is the whole point of it.
    const width = Math.max(1, Math.round(holder.clientWidth * 0.85));
    const height = Math.max(1, Math.round(holder.clientHeight * 0.85));
    if (canvas.width === width && canvas.height === height) return;
    canvas.width = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
    gl.uniform2f(uResolution, width, height);
  }

  function paint(seconds: number): void {
    // Scrolling past drags the metal sideways, so the band belongs to the page
    // rather than looping in place.
    const box = holder.getBoundingClientRect();
    const through = (window.innerHeight - box.top) / (window.innerHeight + box.height);
    gl.uniform1f(uTime, seconds);
    gl.uniform1f(uSlide, through * 2.2);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    holder.classList.add("lit");
  }

  function loop(now: number): void {
    frame = requestAnimationFrame(loop);
    resize();
    paint(now / 1000);
  }

  holder.prepend(canvas);
  resize();

  new IntersectionObserver((entries) => {
    onScreen = entries.some((entry) => entry.isIntersecting);
    if (onScreen && !frame && !STILL) frame = requestAnimationFrame(loop);
    else if (!onScreen && frame) {
      cancelAnimationFrame(frame);
      frame = 0;
    }
  }).observe(holder);

  if (STILL) paint(1.4);
}

export function startStage(): void {
  metalBand();
  if (STILL) return;
  curtain();
  easedScroll();
}
