/**
 * The moving light behind the hero.
 *
 * This is a fragment shader on a single full-screen triangle: a noise field
 * folded through itself twice — domain warping — which is what makes the light
 * look like it is flowing rather than sliding. There is no scene, no camera and
 * no geometry beyond those three vertices, so a 3D library would have been six
 * hundred kilobytes of machinery to draw one triangle. It is written by hand
 * and has no dependencies.
 *
 * It is decoration, and it behaves like decoration:
 *
 *   - The CSS glow underneath is the real background. This only replaces it
 *     once the context is up and the first frame is drawn, so a machine with no
 *     WebGL, a blocked context, or a driver that gives up mid-session shows the
 *     gradient and never sees a gap.
 *   - It stops when the tab is hidden and when the hero scrolls away.
 *   - It runs at half resolution and about thirty frames a second, because it
 *     is blurred light and nobody can tell.
 *   - Under `prefers-reduced-motion` it draws one frame and stops, which leaves
 *     the picture and removes the movement.
 */

const VERTEX = `
attribute vec2 position;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
}
`;

/*
 * Value noise rather than simplex: this is four octaves of blurred light, and
 * at that scale the two are indistinguishable, while value noise is a third of
 * the instructions and nobody else's code to carry.
 *
 * The output is deliberately premultiplied by its own mask and left opaque —
 * the canvas is composited with `screen`, and screen with black is a no-op, so
 * everything the mask darkens simply disappears instead of needing alpha.
 */
const FRAGMENT = `
precision highp float;

uniform vec2 uResolution;
uniform float uTime;

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

void main() {
  vec2 uv = gl_FragCoord.xy / uResolution.xy;
  float aspect = uResolution.x / uResolution.y;

  vec2 p = uv;
  p.x *= aspect;
  p *= 2.1;

  float t = uTime * 0.055;

  // Two rounds of warping. One looks like drifting fog; two looks like it is
  // being stirred.
  vec2 q = vec2(fbm(p + t), fbm(p + vec2(3.4, 1.2) - t * 0.8));
  vec2 r = vec2(
    fbm(p + 2.3 * q + vec2(1.7, 9.2) + t * 1.1),
    fbm(p + 2.3 * q + vec2(8.3, 2.8) - t * 0.9)
  );
  float f = fbm(p + 2.1 * r);

  // Black, not a dark grey. Under screen blending any non-zero floor lifts the
  // whole section, and a field that is mostly floor becomes fog over the text
  // rather than light behind it.
  vec3 base   = vec3(0.0);
  vec3 accent = vec3(0.788, 0.392, 0.259);
  vec3 warm   = vec3(0.925, 0.600, 0.360);
  vec3 cool   = vec3(0.420, 0.350, 0.600);

  // smoothstep rather than a plain multiply: it keeps most of the field at
  // black and lights only the peaks, which is the difference between wisps of
  // light and an even wash.
  vec3 col = mix(base, accent, smoothstep(0.32, 0.82, f));
  col = mix(col, warm, smoothstep(0.38, 0.88, r.x) * 0.7);
  // One cool pool. A single warm hue over black reads as a colour cast; a
  // second hue reads as light.
  col = mix(col, cool, smoothstep(0.45, 0.92, q.y) * 0.4);
  col += accent * pow(clamp(f, 0.0, 1.0), 4.0) * 0.5;

  // Where the light lives. gl_FragCoord counts from the bottom, so the
  // headline sits high in uv.
  vec2 c = uv - vec2(0.5, 0.68);
  c.x *= aspect * 0.62;
  float bloom = exp(-dot(c, c) * 5.4);

  // Dark again before the bottom edge, so the terminal below is lit by its own
  // shadow rather than by this.
  float fade = smoothstep(0.0, 0.45, uv.y);

  // The last factor is the one that matters: this sits behind body text, and
  // light behind text has to stay well under it.
  float mask = clamp(bloom * fade, 0.0, 1.0) * 0.62;

  // Without a dither the falloff bands visibly on a dark screen: eight bits is
  // not many when the whole image lives in the bottom quarter of the range.
  float dither = (hash(gl_FragCoord.xy) - 0.5) / 255.0;

  gl_FragColor = vec4(col * mask + dither, 1.0);
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

/** Half resolution, and never above one device pixel per CSS pixel. */
const SCALE = 0.5;
const FRAME_MS = 1000 / 30;

export function mountHeroShader(hero: HTMLElement): void {
  const canvas = document.createElement("canvas");
  canvas.className = "shader";
  canvas.setAttribute("aria-hidden", "true");

  const context = canvas.getContext("webgl", {
    alpha: false,
    antialias: false,
    depth: false,
    stencil: false,
    powerPreference: "low-power",
  }) as WebGLRenderingContext | null;
  if (!context) return;

  // Re-bound after the guard so the nested functions below see a context that
  // is not null. `resize` and `draw` are hoisted, so the narrowing from the
  // check above does not reach them on its own.
  const gl = context;

  const program = link(gl);
  if (!program) return;

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  // One triangle large enough to cover the clip volume. A quad would need two
  // triangles and a seam down the diagonal for no benefit.
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);

  const position = gl.getAttribLocation(program, "position");
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

  gl.useProgram(program);
  const uResolution = gl.getUniformLocation(program, "uResolution");
  const uTime = gl.getUniformLocation(program, "uTime");

  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let onScreen = true;
  let frame = 0;
  let last = 0;
  let started = false;

  function resize(): void {
    const width = Math.max(1, Math.round(hero.clientWidth * SCALE));
    const height = Math.max(1, Math.round(hero.clientHeight * SCALE));
    if (canvas.width === width && canvas.height === height) return;
    canvas.width = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
    gl.uniform2f(uResolution, width, height);
  }

  function draw(seconds: number): void {
    gl.uniform1f(uTime, seconds);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    if (!started) {
      // Only now is there something to look at, so only now does the gradient
      // underneath step aside.
      hero.classList.add("has-shader");
      started = true;
    }
  }

  function loop(now: number): void {
    frame = requestAnimationFrame(loop);
    if (now - last < FRAME_MS) return;
    last = now;
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

  canvas.addEventListener("webglcontextlost", (event) => {
    // Without this the context never comes back, and the hero is left with a
    // blank canvas over a gradient that has already stepped aside.
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
    if (still) draw(0);
  }).observe(hero);

  new IntersectionObserver((entries) => {
    onScreen = entries.some((entry) => entry.isIntersecting);
    if (onScreen) start();
    else stop();
  }).observe(hero);

  hero.prepend(canvas);
  resize();

  if (still) draw(0);
  else start();
}
