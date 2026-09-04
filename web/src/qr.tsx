import { t } from "./i18n";

/**
 * A QR code, drawn here rather than fetched.
 *
 * The URL in one of these carries a token that grants command execution on
 * this machine. Sending it to a rendering service to get a picture back would
 * hand that token to a third party, which is the one thing this whole feature
 * is arranged to avoid — so the encoder is small, local, and does exactly as
 * much as pairing needs.
 *
 * Version 5 at error-correction level L: 106 bytes of payload, which fits an
 * address, a port and a forty-character token with room to spare, and no more
 * than that. A general encoder would be several times this size for capacity
 * nobody here will use.
 */

const SIZE = 37; // Version 5: 37 x 37 modules.
const CAPACITY = 106; // Byte mode, error correction L.

/** Galois field tables for the Reed–Solomon remainder. */
const EXP = new Uint8Array(512);
const LOG = new Uint8Array(256);
(() => {
  let x = 1;
  for (let i = 0; i < 255; i += 1) {
    EXP[i] = x;
    LOG[x] = i;
    x <<= 1;
    if (x & 0x100) x ^= 0x11d;
  }
  for (let i = 255; i < 512; i += 1) EXP[i] = EXP[i - 255];
})();

function multiply(a: number, b: number): number {
  return a === 0 || b === 0 ? 0 : EXP[LOG[a] + LOG[b]];
}

/** The generator polynomial for `count` error-correction codewords. */
function generator(count: number): Uint8Array {
  let poly = new Uint8Array([1]);
  for (let i = 0; i < count; i += 1) {
    const next = new Uint8Array(poly.length + 1);
    for (let j = 0; j < poly.length; j += 1) {
      next[j] ^= poly[j];
      next[j + 1] ^= multiply(poly[j], EXP[i]);
    }
    poly = next;
  }
  return poly;
}

function remainder(data: Uint8Array, count: number): Uint8Array {
  const poly = generator(count);
  const out = new Uint8Array(count);
  for (const byte of data) {
    const factor = byte ^ out[0];
    out.copyWithin(0, 1);
    out[count - 1] = 0;
    for (let i = 0; i < count; i += 1) {
      out[i] ^= multiply(poly[i + 1], factor);
    }
  }
  return out;
}

/**
 * The modules of a version-5-L code for `text`, or `null` when it will not fit.
 *
 * Returning null rather than throwing: a payload too long is a thing the
 * caller can show a URL for instead, and a page that crashes because an
 * address was long is worse than one that shows the address.
 */
export function encode(text: string): boolean[][] | null {
  const payload = new TextEncoder().encode(text);
  if (payload.length > CAPACITY) return null;

  // Byte mode, then the length, then the data, then the terminator.
  const bits: number[] = [];
  const push = (value: number, width: number) => {
    for (let i = width - 1; i >= 0; i -= 1) bits.push((value >> i) & 1);
  };
  push(0b0100, 4);
  push(payload.length, 8);
  for (const byte of payload) push(byte, 8);

  const totalData = 108; // Version 5-L: 108 data codewords.
  push(0, Math.min(4, totalData * 8 - bits.length));
  while (bits.length % 8 !== 0) bits.push(0);

  const data = new Uint8Array(totalData);
  for (let i = 0; i < bits.length; i += 8) {
    let byte = 0;
    for (let j = 0; j < 8; j += 1) byte = (byte << 1) | bits[i + j];
    data[i / 8] = byte;
  }
  // Padding alternates 0xEC / 0x11, as the specification requires.
  for (let i = Math.ceil(bits.length / 8); i < totalData; i += 1) {
    data[i] = i % 2 === Math.ceil(bits.length / 8) % 2 ? 0xec : 0x11;
  }

  // Version 5-L is one block of 108 data and 26 error-correction codewords.
  const ec = remainder(data, 26);
  const codewords = new Uint8Array(totalData + 26);
  codewords.set(data);
  codewords.set(ec, totalData);

  return place(codewords);
}

/** Lay the codewords into the module grid, with the fixed patterns. */
function place(codewords: Uint8Array): boolean[][] {
  const modules: (boolean | null)[][] = Array.from({ length: SIZE }, () =>
    Array.from({ length: SIZE }, () => null),
  );

  const finder = (row: number, column: number) => {
    for (let r = -1; r <= 7; r += 1) {
      for (let c = -1; c <= 7; c += 1) {
        const y = row + r;
        const x = column + c;
        if (y < 0 || y >= SIZE || x < 0 || x >= SIZE) continue;
        const edge = r === 0 || r === 6 || c === 0 || c === 6;
        const centre = r >= 2 && r <= 4 && c >= 2 && c <= 4;
        modules[y][x] = edge || centre;
      }
    }
  };
  finder(0, 0);
  finder(0, SIZE - 7);
  finder(SIZE - 7, 0);

  // Alignment pattern; version 5 has one, at 28,28.
  for (let r = -2; r <= 2; r += 1) {
    for (let c = -2; c <= 2; c += 1) {
      modules[28 + r][28 + c] = Math.max(Math.abs(r), Math.abs(c)) !== 1;
    }
  }

  // Timing patterns.
  for (let i = 8; i < SIZE - 8; i += 1) {
    if (modules[6][i] === null) modules[6][i] = i % 2 === 0;
    if (modules[i][6] === null) modules[i][6] = i % 2 === 0;
  }
  modules[SIZE - 8][8] = true; // The one module that is always dark.

  // Format information for level L with mask 0, precomputed.
  const format = 0b111011111000100;
  for (let i = 0; i < 15; i += 1) {
    const bit = ((format >> i) & 1) === 1;
    if (i < 6) modules[i][8] = bit;
    else if (i < 8) modules[i + 1][8] = bit;
    else modules[SIZE - 15 + i][8] = bit;

    if (i < 8) modules[8][SIZE - 1 - i] = bit;
    else if (i < 9) modules[8][15 - i - 1 + 1] = bit;
    else modules[8][15 - i - 1] = bit;
  }

  // The data, snaking up and down two columns at a time.
  let bit = 0;
  let upwards = true;
  for (let right = SIZE - 1; right > 0; right -= 2) {
    if (right === 6) right -= 1; // The timing column is skipped entirely.
    for (let step = 0; step < SIZE; step += 1) {
      const row = upwards ? SIZE - 1 - step : step;
      for (const column of [right, right - 1]) {
        if (modules[row][column] !== null) continue;
        const byte = codewords[bit >> 3] ?? 0;
        let dark = ((byte >> (7 - (bit & 7))) & 1) === 1;
        // Mask 0, which the format bits above declare.
        if ((row + column) % 2 === 0) dark = !dark;
        modules[row][column] = dark;
        bit += 1;
      }
    }
    upwards = !upwards;
  }

  return modules.map((row) => row.map((module) => module === true));
}

/** The code as an SVG, or nothing when the payload will not fit. */
export function QrCode({ text, size = 200 }: { text: string; size?: number }) {
  const modules = encode(text);
  if (!modules) return null;

  const quiet = 2;
  const span = SIZE + quiet * 2;
  const dark: string[] = [];
  modules.forEach((row, y) => {
    row.forEach((on, x) => {
      if (on) dark.push(`M${x + quiet} ${y + quiet}h1v1h-1z`);
    });
  });

  return (
    <svg
      className="qr"
      width={size}
      height={size}
      viewBox={`0 0 ${span} ${span}`}
      shapeRendering="crispEdges"
      role="img"
      aria-label={t("pairing code")}
    >
      <rect width={span} height={span} fill="#fff" />
      <path d={dark.join("")} fill="#000" />
    </svg>
  );
}
