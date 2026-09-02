/**
 * What the desktop host can do that a browser tab cannot.
 *
 * The same bundle is served by `opencli serve` and embedded in the desktop app,
 * so every one of these has to answer "not here" rather than fail: the browser
 * build has no folder chooser, no file paths, and no version to update from.
 */

interface TauriBridge {
  invoke(command: string, args?: Record<string, unknown>): Promise<unknown>;
}

interface TauriEvents {
  listen(event: string, handler: (message: { payload: unknown }) => void): Promise<() => void>;
}

export function bridge(): TauriBridge | null {
  return (window as unknown as { __TAURI__?: { core?: TauriBridge } }).__TAURI__?.core ?? null;
}

function events(): TauriEvents | null {
  return (window as unknown as { __TAURI__?: { event?: TauriEvents } }).__TAURI__?.event ?? null;
}

export function isDesktop(): boolean {
  return bridge() !== null;
}

/** Listen for an event the host emits; a no-op unsubscribe in the browser. */
export async function onHostEvent(
  name: string,
  handler: (payload: unknown) => void,
): Promise<() => void> {
  const bus = events();
  if (!bus) return () => {};
  try {
    return await bus.listen(name, (message) => handler(message.payload));
  } catch {
    return () => {};
  }
}

/**
 * Ask the desktop host for a value it alone knows: the gateway binds a random
 * port at startup, and a desktop launch has no shell to inherit a directory
 * from. Returns `null` in the browser build, where the user supplies both.
 */
export async function fromHost(
  command: "gateway_url" | "default_cwd" | "app_version",
): Promise<string | null> {
  const core = bridge();
  if (!core) return null;
  try {
    const value = await core.invoke(command);
    return typeof value === "string" ? value : null;
  } catch {
    return null;
  }
}

/**
 * Open the platform's file chooser, if the host offers one.
 *
 * Only the desktop build can attach a file: the browser hands over a `File`
 * with no path, and a path is what the agent needs to read it.
 */
export async function chooseFiles(): Promise<{ name: string; path: string }[]> {
  const core = bridge();
  if (!core) return [];
  try {
    const chosen = await core.invoke("choose_files");
    if (!Array.isArray(chosen)) return [];
    return chosen
      .filter((path): path is string => typeof path === "string" && path.length > 0)
      .map((path) => ({ name: path.split("/").pop() || path, path }));
  } catch {
    return [];
  }
}

/** Show a file in the platform's file manager; nothing to do in a browser. */
export function revealPath(path: string): void {
  void bridge()?.invoke("reveal_path", { path });
}

/**
 * Open the platform's folder chooser, if the host offers one.
 *
 * Returns `null` in the browser build and when the user cancels — in both
 * cases the caller should leave whatever path is already there.
 */
export async function chooseDirectory(start: string): Promise<string | null> {
  const core = bridge();
  if (!core) return null;
  try {
    const chosen = await core.invoke("choose_directory", { start });
    return typeof chosen === "string" && chosen ? chosen : null;
  } catch {
    return null;
  }
}
