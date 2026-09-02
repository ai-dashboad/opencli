/**
 * The two things this site does with JavaScript.
 *
 * Everything else is in the HTML, and works without this file: the download
 * page lists every file for every platform, and the install command is written
 * out in full. This only sharpens it — picking the visitor's platform out of
 * the list, and filling in the version number once GitHub answers.
 *
 * Both degrade to "all the links are still there", which is why neither is
 * awaited before anything is shown.
 */

const REPO = "ai-dashboad/opencli";

type Platform = "macos-arm" | "macos-intel" | "windows" | "linux" | "unknown";

/**
 * Which build this visitor most likely wants.
 *
 * Apple Silicon cannot be read from the user agent — Safari and Chrome both
 * report Intel on every Mac. `navigator.platform` says `MacIntel` regardless,
 * so the count of logical cores is used as the tell: Apple Silicon Macs have at
 * least 8, and the Intel Macs still in use rarely do. A wrong guess is not
 * costly here, because the other file is one line below the button.
 */
export function detectPlatform(ua: string, cores: number): Platform {
  const agent = ua.toLowerCase();
  if (agent.includes("windows")) return "windows";
  if (agent.includes("mac os x") || agent.includes("macintosh")) {
    return cores >= 8 ? "macos-arm" : "macos-intel";
  }
  if (agent.includes("linux") || agent.includes("x11")) return "linux";
  return "unknown";
}

const LABELS: Record<Platform, string> = {
  "macos-arm": "Download for macOS (Apple Silicon)",
  "macos-intel": "Download for macOS (Intel)",
  windows: "Download for Windows",
  linux: "Download for Linux",
  unknown: "See all downloads",
};

/**
 * The release asset each platform's main button points at.
 *
 * These names carry no version, which is the point: the release workflow
 * uploads a copy under a stable name so that this list, the README and every
 * link anyone shares keep working across releases.
 */
const ASSETS: Record<Platform, string | null> = {
  "macos-arm": "OpenCLI-macos-aarch64.dmg",
  "macos-intel": "OpenCLI-macos-x86_64.dmg",
  windows: "OpenCLI-windows-x86_64-setup.exe",
  linux: "OpenCLI-linux-x86_64.AppImage",
  unknown: null,
};

function latestDownload(asset: string): string {
  return `https://github.com/${REPO}/releases/latest/download/${asset}`;
}

/** Fill in the main download button for whoever is looking at it. */
function setUpDownload(): void {
  const button = document.querySelector<HTMLAnchorElement>("[data-download-main]");
  if (!button) return;

  const platform = detectPlatform(navigator.userAgent, navigator.hardwareConcurrency ?? 0);
  const asset = ASSETS[platform];
  button.textContent = LABELS[platform];
  button.href = asset ? latestDownload(asset) : "/download.html#all";

  const detail = document.querySelector<HTMLElement>("[data-download-detail]");
  if (detail && platform !== "unknown") {
    detail.hidden = false;
  }
}

/**
 * Say which version the buttons will fetch.
 *
 * Unauthenticated GitHub API calls are rate-limited per IP, so a failure here
 * is expected rather than exceptional: the version simply stays unstated, and
 * every link still resolves to the latest release.
 */
async function showLatestVersion(): Promise<void> {
  const blocks = document.querySelectorAll<HTMLElement>("[data-version-block]");
  if (blocks.length === 0) return;
  try {
    const response = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`);
    if (!response.ok) return;
    const release = (await response.json()) as { tag_name?: string };
    if (!release.tag_name) return;
    const version = release.tag_name.replace(/^v/, "");
    for (const block of blocks) {
      const slot = block.querySelector<HTMLElement>("[data-version]");
      if (slot) slot.textContent = version;
      // Revealed only now: a version number shown as a dash while it loads is
      // worse than one that was never promised.
      block.hidden = false;
    }
  } catch {
    // Offline, rate-limited, or no release yet. The links do not depend on it.
  }
}

/** Copy the install command, since that is the only reason it is on screen. */
function setUpCopy(): void {
  for (const button of document.querySelectorAll<HTMLButtonElement>("[data-copy]")) {
    button.addEventListener("click", () => {
      const text = button.getAttribute("data-copy") ?? "";
      void navigator.clipboard.writeText(text).then(() => {
        const was = button.textContent;
        button.textContent = "Copied";
        setTimeout(() => {
          button.textContent = was;
        }, 1400);
      });
    });
  }
}

setUpDownload();
setUpCopy();
void showLatestVersion();
