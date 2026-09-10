import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

/**
 * Ordered by what somebody does, not by what the parts are called.
 *
 * Somebody arriving has installed nothing, so installing comes first; somebody
 * who has it working wants to know what to do with it, so the work comes
 * before the configuration that tunes it. Reference last, because it is
 * looked up rather than read.
 */
const sidebars: SidebarsConfig = {
  docs: [
    "index",
    {
      type: "category",
      label: "Getting started",
      collapsed: false,
      items: [
        "getting-started/install",
        "getting-started/point-at-a-model",
        "getting-started/first-conversation",
      ],
    },
    {
      type: "category",
      label: "Doing work",
      collapsed: false,
      items: [
        "doing-work/departments-and-bots",
        "doing-work/duties",
        "doing-work/background-runs",
        "doing-work/skills",
        "doing-work/connectors",
      ],
    },
    {
      type: "category",
      label: "Configuration",
      items: [
        "configuration/config-file",
        "configuration/sandbox-and-approvals",
        "configuration/languages",
      ],
    },
    {
      type: "category",
      label: "Reference",
      items: ["reference/checking-a-model", "reference/limits", "reference/contributing"],
    },
  ],
};

export default sidebars;
