import { describe, expect, it } from "vitest";

import { encode } from "./qr";

/**
 * The payload of one of these grants command execution on this machine, which
 * is why it is drawn here instead of fetched from a service. These check the
 * encoder does the job pairing needs — not that it is a general one.
 */
describe("the pairing code", () => {
  it("should encode a pairing URL", () => {
    const modules = encode(
      "ws://100.83.12.4:4517/ws?token=abcdefghijkmnopqrstuvwxyz23456789abcdefgh",
    );
    expect(modules).not.toBeNull();
    expect(modules).toHaveLength(37);
    expect(modules?.[0]).toHaveLength(37);
  });

  it("should place the three finder patterns", () => {
    // Without these a scanner never finds the code at all, and every other
    // byte being right would not matter.
    const modules = encode("ws://10.0.0.2:4517/ws?token=x")!;
    for (const [row, column] of [
      [0, 0],
      [0, 30],
      [30, 0],
    ]) {
      expect(modules[row][column], `finder at ${row},${column}`).toBe(true);
      expect(modules[row + 1][column + 1]).toBe(false);
      expect(modules[row + 3][column + 3]).toBe(true);
    }
  });

  it("should say no rather than truncating a payload that will not fit", () => {
    // Silently cutting it would produce a code that scans and yields a token
    // missing its last characters — which fails at connection time, far from
    // here.
    expect(encode("x".repeat(200))).toBeNull();
  });

  it("should encode the longest URL pairing can produce", () => {
    // An IPv4 address, a port, and a forty-character token.
    const longest = `ws://255.255.255.255:65535/ws?token=${"a".repeat(40)}`;
    expect(encode(longest)).not.toBeNull();
  });

  it("should differ for different payloads", () => {
    const one = encode("ws://10.0.0.2:4517/ws?token=aaaa")!;
    const two = encode("ws://10.0.0.2:4517/ws?token=bbbb")!;
    expect(JSON.stringify(one)).not.toBe(JSON.stringify(two));
  });
});
