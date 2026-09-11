/**
 * A word, turned into a distance field.
 *
 * The mark in the hero is raymarched, which means the shader needs to answer
 * "how far is this point from the surface" for any point in space. For the
 * chevron that was three line segments and a little algebra. For a word it is
 * not: letterforms are outlines with curves, counters and joins, and writing
 * them out as primitives would be approximating a typeface that is already
 * installed.
 *
 * So the word is drawn into an offscreen canvas with the same font stack the
 * page uses, and that bitmap is turned into a true Euclidean distance field —
 * every pixel carrying its distance to the nearest edge, inside negative and
 * outside positive. The shader samples it as a texture and extrudes it.
 *
 * The transform is Felzenszwalb and Huttenlocher's: a one-dimensional pass
 * down the columns and another across the rows, each linear in the number of
 * pixels. It is exact, unlike the chamfer approximations that are easier to
 * write, and exactness matters here — a raymarcher steps by the distance it is
 * given, so a field that overstates it will step straight through the surface.
 */

/**
 * The lower envelope of a set of parabolas, one per pixel.
 *
 * `f` is the squared distance known so far for each cell in a row or column;
 * this replaces it with the distance to the nearest cell in that line. The
 * scratch arrays are passed in rather than allocated because this runs once
 * per row and once per column.
 */
function pass(f: Float64Array, d: Float64Array, v: Int32Array, z: Float64Array, n: number): void {
  let k = 0;
  v[0] = 0;
  z[0] = -Infinity;
  z[1] = Infinity;

  for (let q = 1; q < n; q++) {
    let s = (f[q] + q * q - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
    while (s <= z[k]) {
      k--;
      s = (f[q] + q * q - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
    }
    k++;
    v[k] = q;
    z[k] = s;
    z[k + 1] = Infinity;
  }

  k = 0;
  for (let q = 0; q < n; q++) {
    while (z[k + 1] < q) k++;
    const dist = q - v[k];
    d[q] = dist * dist + f[v[k]];
  }
}

/** Squared distance from every cell to the nearest cell that is `true`. */
function transform(mask: Uint8Array, width: number, height: number, wanted: number): Float64Array {
  const out = new Float64Array(width * height);
  const long = Math.max(width, height);
  const f = new Float64Array(long);
  const d = new Float64Array(long);
  const v = new Int32Array(long);
  const z = new Float64Array(long + 1);

  for (let i = 0; i < out.length; i++) {
    out[i] = mask[i] === wanted ? 0 : Infinity;
  }

  for (let x = 0; x < width; x++) {
    for (let y = 0; y < height; y++) f[y] = out[y * width + x];
    pass(f, d, v, z, height);
    for (let y = 0; y < height; y++) out[y * width + x] = d[y];
  }

  for (let y = 0; y < height; y++) {
    const row = y * width;
    for (let x = 0; x < width; x++) f[x] = out[row + x];
    pass(f, d, v, z, width);
    for (let x = 0; x < width; x++) out[row + x] = d[x];
  }

  return out;
}

export type Field = {
  data: Uint8Array;
  width: number;
  height: number;
  /** Width over height, so the shader can lay the word out square. */
  aspect: number;
  /**
   * How many object-space units the encoded range covers. A byte holds
   * 0…255 and the field is signed, so the encoding is
   * `(distance / spread) * 0.5 + 0.5` in units of the field's height.
   */
  spread: number;
};

/**
 * Half the encoded range, in pixels. Beyond it the field saturates.
 *
 * Kept deliberately small. A byte has 256 values however wide the range is, so
 * a generous reach buys distance at the cost of precision — at ±56px one step
 * of the encoding was 0.0014 object units while the raymarcher's hit threshold
 * was 0.0016, meaning the surface was thinner than the noise and the letters
 * came out sliced. The field only has to be accurate *near* the glyph; the
 * shader's bounding box gives the correct distance everywhere else.
 */
const REACH = 20;

/**
 * Draw the word and measure it.
 *
 * The font stack is the page's own, so the metal says the word in the same
 * letters the rest of the site does — whatever that resolves to on the machine
 * looking at it.
 */
export function fieldFor(word: string): Field | null {
  const size = 320;
  const pad = REACH + 16;

  const measure = document.createElement("canvas").getContext("2d");
  if (!measure) return null;

  const font = `620 ${size}px ui-sans-serif, -apple-system, "SF Pro Display", system-ui, sans-serif`;
  measure.font = font;
  const box = measure.measureText(word);
  const ink = Math.ceil(box.actualBoundingBoxAscent + box.actualBoundingBoxDescent);
  const width = Math.ceil(box.width) + pad * 2;
  const height = ink + pad * 2;

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) return null;

  ctx.font = font;
  ctx.fillStyle = "#fff";
  ctx.textBaseline = "alphabetic";
  ctx.fillText(word, pad, pad + box.actualBoundingBoxAscent);

  const pixels = ctx.getImageData(0, 0, width, height).data;
  const alpha = new Uint8Array(width * height);
  const mask = new Uint8Array(width * height);
  for (let i = 0; i < mask.length; i++) {
    alpha[i] = pixels[i * 4 + 3];
    mask[i] = alpha[i] > 127 ? 1 : 0;
  }

  const outside = transform(mask, width, height, 1);
  const inside = transform(mask, width, height, 0);

  const data = new Uint8Array(width * height);
  for (let i = 0; i < data.length; i++) {
    let signed = mask[i] === 1 ? -Math.sqrt(inside[i]) : Math.sqrt(outside[i]);

    /*
     * On the boundary itself, take the distance from the coverage instead.
     *
     * The transform is exact, but it is exact about a *binary* mask, and
     * thresholding threw away the one thing that knew where the edge really
     * was: a pixel 30% covered has its edge 0.2px inside it, not on whichever
     * side of the halfway mark it landed. Without this the outlines come back
     * with the pixel grid still visible in them.
     */
    const coverage = alpha[i] / 255;
    if (Math.abs(signed) <= 1.5 && coverage > 0 && coverage < 1) {
      signed = 0.5 - coverage;
    }

    const scaled = Math.max(0, Math.min(1, signed / (REACH * 2) + 0.5));
    data[i] = Math.round(scaled * 255);
  }

  return {
    data,
    width,
    height,
    aspect: width / height,
    spread: (REACH * 2) / height,
  };
}
