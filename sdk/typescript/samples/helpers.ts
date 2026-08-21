import path from "node:path";

export function opencliPathOverride() {
  return (
    process.env.OPENCLI_EXECUTABLE ??
    path.join(process.cwd(), "..", "..", "opencli-rs", "target", "debug", "opencli")
  );
}
