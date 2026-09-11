/**
 * The hero's backdrop, and the mark standing in it.
 *
 * This used to be a gradient. It is now a raymarched scene: the OpenCLI mark —
 * the `<` and the underscore that make a prompt — extruded into a solid, given
 * a chrome surface, and lit by a small procedural studio. There is no geometry
 * and no scene graph, because a signed distance field needs neither: the shape
 * is an equation, the surface normal is its gradient, and the reflection is one
 * more ray. A 3D library would have been a hundred and fifty kilobytes to hold
 * six vertices this file does not have.
 *
 * The canvas is opaque and owns the whole hero background — the fog, the light
 * and the mark are one image. That is the only way the chrome can be *darker*
 * than what sits behind it: screen blending, which the gradient version used,
 * can only ever add light, and a mirror that cannot go dark is not a mirror.
 *
 * It behaves like decoration, as before. The CSS gradient underneath stays as
 * the floor and is only crossed to once a first frame exists, it stops when the
 * tab is hidden or the hero scrolls away, and under `prefers-reduced-motion` it
 * draws one still frame.
 */

const VERTEX = `
attribute vec2 position;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
}
`;

const FRAGMENT = `
precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform vec2 uPointer;
uniform float uScroll;
uniform vec2 uCenter;
uniform float uScale;

/* ── the backdrop ──────────────────────────────────────────────────── */

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float total = 0.0;
  float amplitude = 0.5;
  for (int octave = 0; octave < 4; octave++) {
    total += amplitude * noise(p);
    p *= 2.03;
    amplitude *= 0.5;
  }
  return total;
}

vec3 backdrop(vec2 uv) {
  float aspect = uResolution.x / uResolution.y;
  vec2 p = uv;
  p.x *= aspect;
  p *= 2.1;

  float t = uTime * 0.05;
  vec2 q = vec2(fbm(p + t), fbm(p + vec2(3.4, 1.2) - t * 0.8));
  vec2 r = vec2(
    fbm(p + 2.3 * q + vec2(1.7, 9.2) + t * 1.1),
    fbm(p + 2.3 * q + vec2(8.3, 2.8) - t * 0.9)
  );
  float f = fbm(p + 2.1 * r);

  vec3 accent = vec3(0.788, 0.392, 0.259);
  vec3 warm   = vec3(0.925, 0.600, 0.360);
  vec3 cool   = vec3(0.420, 0.350, 0.600);

  vec3 fog = mix(vec3(0.0), accent, smoothstep(0.32, 0.82, f));
  fog = mix(fog, warm, smoothstep(0.38, 0.88, r.x) * 0.7);
  fog = mix(fog, cool, smoothstep(0.45, 0.92, q.y) * 0.4);

  vec2 c = uv - vec2(0.5, 0.62);
  c.x *= aspect * 0.7;
  float bloom = exp(-dot(c, c) * 4.4);
  float lift = smoothstep(0.0, 0.45, uv.y);

  // Dark at the top, and arriving at the page's own background by the bottom
  // edge so the section below continues rather than starts.
  vec3 page = vec3(0.149, 0.149, 0.141);
  vec3 base = mix(page, vec3(0.074, 0.070, 0.066), smoothstep(0.0, 0.62, uv.y));

  return base + fog * bloom * lift * 0.5;
}

/* ── the mark, as a distance field ─────────────────────────────────── */

float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

/*
 * The glyph, in the favicon's own proportions: a chevron from (17,9) to (9,16)
 * to (17,23), then an underscore running out to (25,23), all measured in a
 * 32-unit box and shifted so the middle of that box is the origin.
 */
float glyph(vec3 p) {
  vec2 a = vec2(0.0625, 0.4375);
  vec2 b = vec2(-0.4375, 0.0);
  vec2 c = vec2(0.0625, -0.4375);
  vec2 d = vec2(0.5625, -0.4375);

  float stroke = min(min(segment(p.xy, a, b), segment(p.xy, b, c)), segment(p.xy, c, d));

  stroke -= 0.105 + 0.014 * sin(p.y * 7.0 + uTime * 0.9) * cos(p.x * 5.0 - uTime * 0.6);

  // The face has to move, or it is not liquid.
  //
  // A flat surface reflects exactly one direction of the environment, which is
  // why a flat chrome face looks like painted plastic: there is nothing in the
  // reflection to see. Rippling the front and back makes the reflection sweep
  // across it, and that sweep is the whole impression of molten metal.
  float swell =
      sin(p.x * 5.4 + uTime * 0.75) * sin(p.y * 4.6 - uTime * 0.55) +
      0.5 * sin(p.y * 9.1 + uTime * 1.15);

  vec2 w = vec2(stroke, abs(p.z) - (0.10 + 0.042 * swell));
  return min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - 0.05;
}

mat3 spin(float yaw, float pitch) {
  float cy = cos(yaw);
  float sy = sin(yaw);
  float cp = cos(pitch);
  float sp = sin(pitch);
  return mat3(cy, 0.0, -sy, sp * sy, cp, sp * cy, cp * sy, -sp, cp * cy);
}

mat3 pose() {
  float yaw = uPointer.x * 0.5 + sin(uTime * 0.28) * 0.26 + uScroll * 1.4;
  float pitch = -uPointer.y * 0.34 + sin(uTime * 0.21) * 0.11 + uScroll * 0.3;
  return spin(yaw, pitch);
}

float scene(vec3 p, mat3 m) {
  return glyph((p / uScale) * m) * uScale;
}

vec3 normalAt(vec3 p, mat3 m) {
  vec2 e = vec2(0.0016, 0.0);
  return normalize(vec3(
    scene(p + e.xyy, m) - scene(p - e.xyy, m),
    scene(p + e.yxy, m) - scene(p - e.yxy, m),
    scene(p + e.yyx, m) - scene(p - e.yyx, m)
  ));
}

/*
 * A studio, made up rather than loaded: a bright soft ceiling, a dark floor,
 * one hard white strip light and one warm one. Chrome is nothing but a mirror,
 * so the entire look of the material is this function.
 */
vec3 studio(vec3 rd) {
  float up = rd.y * 0.5 + 0.5;
  vec3 col = mix(vec3(0.02, 0.02, 0.022), vec3(0.62, 0.63, 0.66), pow(up, 1.35));

  // Two hard white strips. Polished metal is read almost entirely from the
  // shape of the lights it reflects, so these are the material.
  float key = smoothstep(0.13, 0.0, abs(rd.y - 0.6)) * smoothstep(1.1, 0.1, abs(rd.x + 0.3));
  col += vec3(1.0, 0.99, 0.98) * key * 4.2;

  float second = smoothstep(0.09, 0.0, abs(rd.y - 0.18)) * smoothstep(1.0, 0.15, abs(rd.x - 0.62));
  col += vec3(0.96, 0.97, 1.0) * second * 2.6;

  // One warm strip, low, so the silver picks up the page's colour without
  // turning into copper.
  float fill = smoothstep(0.22, 0.0, abs(rd.y + 0.12)) * smoothstep(1.2, 0.25, abs(rd.x - 0.85));
  col += vec3(0.98, 0.58, 0.36) * fill * 1.15;

  float rim = smoothstep(0.1, 0.0, abs(rd.y + 0.58)) * smoothstep(1.0, 0.1, abs(rd.z - 0.6));
  col += vec3(0.5, 0.44, 0.72) * rim * 0.9;

  return col;
}

void main() {
  vec2 uv = gl_FragCoord.xy / uResolution.xy;
  vec3 colour = backdrop(uv);

  // Camera space, with the mark placed where the layout wants it.
  vec2 screen = (gl_FragCoord.xy - 0.5 * uResolution.xy) / uResolution.y;
  screen -= uCenter;

  vec3 ro = vec3(0.0, 0.0, 2.6 + uScroll * 1.1);
  vec3 rd = normalize(vec3(screen, -1.7));

  mat3 m = pose();

  float travelled = 0.0;
  bool hit = false;
  for (int step = 0; step < 72; step++) {
    vec3 at = ro + rd * travelled;
    float dist = scene(at, m);
    if (dist < 0.0016) {
      hit = true;
      break;
    }
    travelled += dist * 0.78;
    if (travelled > 6.0) break;
  }

  if (hit) {
    vec3 at = ro + rd * travelled;
    vec3 n = normalAt(at, m);
    vec3 view = normalize(ro - at);

    vec3 metal = studio(reflect(-view, n));

    // Chrome is almost entirely reflection; the fresnel term is what stops the
    // edges going flat wherever the reflection happens to be dark.
    float fres = pow(1.0 - max(dot(n, view), 0.0), 3.4);
    metal += vec3(0.98, 0.62, 0.44) * fres * 0.7;
    metal *= 0.97;

    // One tight highlight, so the surface has somewhere to catch the eye.
    vec3 lightDir = normalize(vec3(-0.4, 0.8, 0.5));
    float spec = pow(max(dot(reflect(-lightDir, n), view), 0.0), 90.0);
    metal += vec3(1.0) * spec * 1.3;

    colour = metal;

    // The light it throws back into the fog around it.
    colour += vec3(0.9, 0.45, 0.28) * fres * 0.12;
  }

  float dither = (hash(gl_FragCoord.xy) - 0.5) / 255.0;
  gl_FragColor = vec4(colour + dither, 1.0);
}
`;

function compile(gl: WebGLRenderingContext, type: number, source: string): WebGLShader | null {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

function link(gl: WebGLRenderingContext): WebGLProgram | null {
  const vertex = compile(gl, gl.VERTEX_SHADER, VERTEX);
  const fragment = compile(gl, gl.FRAGMENT_SHADER, FRAGMENT);
  if (!vertex || !fragment) return null;

  const program = gl.createProgram();
  if (!program) return null;
  gl.attachShader(program, vertex);
  gl.attachShader(program, fragment);
  gl.linkProgram(program);
  gl.deleteShader(vertex);
  gl.deleteShader(fragment);

  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    gl.deleteProgram(program);
    return null;
  }
  return program;
}

/** Raymarching costs a lot per pixel, so it is not given many of them. */
const SCALE = 0.65;
const FLOOR = 0.3;
const FRAME_MS = 1000 / 60;

export function mountHeroShader(hero: HTMLElement): void {
  const canvas = document.createElement("canvas");
  canvas.className = "shader";
  canvas.setAttribute("aria-hidden", "true");

  const context = canvas.getContext("webgl", {
    alpha: false,
    antialias: false,
    depth: false,
    stencil: false,
    powerPreference: "high-performance",
  }) as WebGLRenderingContext | null;
  if (!context) return;

  const gl = context;
  const program = link(gl);
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
  const uPointer = gl.getUniformLocation(program, "uPointer");
  const uScroll = gl.getUniformLocation(program, "uScroll");
  const uCenter = gl.getUniformLocation(program, "uCenter");
  const uScale = gl.getUniformLocation(program, "uScale");

  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let onScreen = true;
  let frame = 0;
  let last = 0;
  let started = false;

  /** Dropped when frames get long. It only ever steps down. */
  let quality = 1;
  let slow = 0;

  let pointerX = 0;
  let pointerY = 0;
  let aimX = 0;
  let aimY = 0;
  let scroll = 0;

  /**
   * Beside the words on a wide screen, above them on a narrow one.
   *
   * `x` is in the shader's own space, where one unit is the height of the hero
   * and the origin is its middle — so 0.34 puts the mark about three quarters
   * of the way across a 16:9 screen, clear of the column the text is in.
   */
  function placement(): { x: number; y: number; scale: number } {
    return hero.clientWidth > 900
      ? { x: 0.3, y: 0.26, scale: 0.22 }
      : { x: 0, y: 0.36, scale: 0.15 };
  }

  function resize(): void {
    const width = Math.max(1, Math.round(hero.clientWidth * SCALE * quality));
    const height = Math.max(1, Math.round(hero.clientHeight * SCALE * quality));
    if (canvas.width === width && canvas.height === height) return;
    canvas.width = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
    gl.uniform2f(uResolution, width, height);
  }

  function draw(seconds: number): void {
    const where = placement();
    gl.uniform1f(uTime, seconds);
    gl.uniform2f(uPointer, pointerX, pointerY);
    gl.uniform1f(uScroll, scroll);
    gl.uniform2f(uCenter, where.x, where.y);
    gl.uniform1f(uScale, where.scale);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    if (!started) {
      hero.classList.add("has-shader");
      started = true;
    }
  }

  function loop(now: number): void {
    frame = requestAnimationFrame(loop);
    const since = now - last;
    if (since < FRAME_MS) return;

    // A machine that cannot hold the frame rate gets fewer pixels rather than a
    // slideshow.
    if (last && since > 34 && quality > FLOOR) {
      if (++slow > 12) {
        quality = Math.max(FLOOR, quality - 0.18);
        slow = 0;
        canvas.width = 0;
      }
    } else if (since < 22) {
      slow = Math.max(0, slow - 1);
    }
    last = now;

    // Eased towards the pointer, so the mark swings rather than snaps.
    pointerX += (aimX - pointerX) * 0.06;
    pointerY += (aimY - pointerY) * 0.06;

    const box = hero.getBoundingClientRect();
    scroll = Math.max(0, Math.min(1, -box.top / Math.max(1, box.height)));

    resize();
    draw(now / 1000);
  }

  function start(): void {
    if (frame || still || document.hidden || !onScreen) return;
    last = 0;
    frame = requestAnimationFrame(loop);
  }

  function stop(): void {
    if (!frame) return;
    cancelAnimationFrame(frame);
    frame = 0;
  }

  window.addEventListener(
    "pointermove",
    (event) => {
      const box = hero.getBoundingClientRect();
      aimX = ((event.clientX - box.left) / Math.max(1, box.width)) * 2 - 1;
      aimY = ((event.clientY - box.top) / Math.max(1, box.height)) * 2 - 1;
    },
    { passive: true },
  );

  canvas.addEventListener("webglcontextlost", (event) => {
    event.preventDefault();
    stop();
    hero.classList.remove("has-shader");
    started = false;
  });

  canvas.addEventListener("webglcontextrestored", () => {
    canvas.remove();
    mountHeroShader(hero);
  });

  document.addEventListener("visibilitychange", () => (document.hidden ? stop() : start()));

  new ResizeObserver(() => {
    resize();
    if (still) draw(2.2);
  }).observe(hero);

  new IntersectionObserver((entries) => {
    onScreen = entries.some((entry) => entry.isIntersecting);
    if (onScreen) start();
    else stop();
  }).observe(hero);

  hero.prepend(canvas);
  resize();

  if (still) draw(2.2);
  else start();
}
