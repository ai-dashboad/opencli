/**
 * Keeping the desktop app current.
 *
 * The app is not signed, so the first install goes past a warning the user has
 * to be told about. Every install after that should not: updating is the one
 * part of this we can make quiet, and an agent people leave open for days is
 * exactly the kind of program that otherwise stays three versions behind.
 *
 * Deliberately not a dialog. Nothing here is urgent enough to interrupt a
 * conversation, and a modal that appears over a half-written prompt is how
 * update prompts earn the reflex to dismiss them unread. It is a line in the
 * sidebar, and it waits.
 */

import { useCallback, useEffect, useState } from "react";
import { bridge, isDesktop, onHostEvent } from "./host";

export type UpdateStage = "none" | "available" | "downloading" | "ready" | "failed";

export interface UpdateState {
  stage: UpdateStage;
  /** The version on offer, once one is known. */
  version: string | null;
  /** 0–1 while downloading, or null when the server declares no length. */
  progress: number | null;
  error: string | null;
  install: () => void;
  restart: () => void;
  dismiss: () => void;
}

/** How long to wait before asking. Starting up is busy enough. */
const FIRST_CHECK_MS = 8000;

/** And how often after that, for a window left open for days. */
const EVERY_MS = 6 * 60 * 60 * 1000;

export function useUpdate(): UpdateState {
  const [stage, setStage] = useState<UpdateStage>("none");
  const [version, setVersion] = useState<string | null>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    if (!isDesktop()) return;
    let stopped = false;

    const check = async () => {
      const core = bridge();
      if (!core || stopped) return;
      try {
        const found = (await core.invoke("check_update")) as { version?: string } | null;
        if (stopped || !found?.version) return;
        setVersion(found.version);
        // A download already under way must not be reset by a routine check.
        setStage((current) => (current === "none" ? "available" : current));
      } catch {
        // Being offline is not a failure worth a line in the sidebar.
      }
    };

    const first = setTimeout(() => void check(), FIRST_CHECK_MS);
    const repeat = setInterval(() => void check(), EVERY_MS);
    return () => {
      stopped = true;
      clearTimeout(first);
      clearInterval(repeat);
    };
  }, []);

  useEffect(() => {
    if (!isDesktop()) return;
    let unlisten: (() => void) | null = null;
    void onHostEvent("update://progress", (payload) => {
      if (!Array.isArray(payload)) return;
      const [downloaded, total] = payload as [number, number | null];
      setProgress(typeof total === "number" && total > 0 ? downloaded / total : null);
    }).then((off) => {
      unlisten = off;
    });
    return () => unlisten?.();
  }, []);

  const install = useCallback(() => {
    const core = bridge();
    if (!core) return;
    setStage("downloading");
    setProgress(0);
    setError(null);
    void core
      .invoke("install_update")
      .then(() => setStage("ready"))
      .catch((err: unknown) => {
        setError(err instanceof Error ? err.message : String(err));
        setStage("failed");
      });
  }, []);

  const restart = useCallback(() => {
    void bridge()?.invoke("restart_app");
  }, []);

  const dismiss = useCallback(() => setDismissed(true), []);

  return {
    // Dismissing hides the offer, but not a download that is already finished:
    // the app has been replaced on disk by then, and saying nothing about it
    // would leave the running copy quietly out of date until the next launch.
    stage: dismissed && stage === "available" ? "none" : stage,
    version,
    progress,
    error,
    install,
    restart,
    dismiss,
  };
}
