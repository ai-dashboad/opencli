import type * as Preset from "@docusaurus/preset-classic";
import type { Config } from "@docusaurus/types";
import { themes as prismThemes } from "prism-react-renderer";

/**
 * The documentation site.
 *
 * Docs only: no blog, and no landing page of its own — `opencli.ai` is the
 * landing page and this is what it links into. `routeBasePath: "/"` puts the
 * first page at the root of `docs.opencli.ai` rather than at `/docs/docs`.
 */
const config: Config = {
  title: "OpenCLI",
  tagline: "The agent for the models that do not have one",
  favicon: "img/favicon.svg",

  url: "https://docs.opencli.ai",
  baseUrl: "/",
  organizationName: "ai-dashboad",
  projectName: "opencli",

  // A dead link in documentation is worse than a missing page: it looks like
  // the answer exists and has been mislaid.
  onBrokenLinks: "throw",
  markdown: { hooks: { onBrokenMarkdownLinks: "throw" } },

  i18n: { defaultLocale: "en", locales: ["en"] },

  presets: [
    [
      "classic",
      {
        docs: {
          routeBasePath: "/",
          sidebarPath: "./sidebars.ts",
          editUrl: "https://github.com/ai-dashboad/opencli/tree/main/docs-site/",
        },
        blog: false,
        theme: { customCss: "./src/css/custom.css" },
      } satisfies Preset.Options,
    ],
  ],

  // Search that ships with the site rather than calling one.
  //
  // Algolia is what Docusaurus reaches for by default and it means a hosted
  // index, an account, and a crawler that has to be let in. A local index is
  // a file in the build: it works offline, it works behind a firewall, and a
  // reader searching the docs does not tell a third party what they searched
  // for.
  themes: [
    [
      "@easyops-cn/docusaurus-search-local",
      { hashed: true, indexBlog: false, docsRouteBasePath: "/" },
    ],
  ],

  themeConfig: {
    navbar: {
      title: "OpenCLI",
      logo: { alt: "OpenCLI", src: "img/logo.svg" },
      items: [
        { type: "docSidebar", sidebarId: "docs", position: "left", label: "Docs" },
        { href: "https://opencli.ai/download.html", label: "Download", position: "right" },
        { href: "https://github.com/ai-dashboad/opencli", label: "GitHub", position: "right" },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "Start here",
          items: [
            { label: "Install", to: "/getting-started/install" },
            { label: "Point it at a model", to: "/getting-started/point-at-a-model" },
          ],
        },
        {
          title: "Elsewhere",
          items: [
            { label: "opencli.ai", href: "https://opencli.ai" },
            { label: "GitHub", href: "https://github.com/ai-dashboad/opencli" },
            { label: "Issues", href: "https://github.com/ai-dashboad/opencli/issues" },
          ],
        },
      ],
      copyright: `OpenCLI · Apache-2.0 · a fork of <a href="https://github.com/openai/codex">OpenAI Codex CLI</a>, not affiliated with OpenAI`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ["toml", "bash", "json", "yaml"],
    },
    colorMode: { defaultMode: "dark", respectPrefersColorScheme: true },
  } satisfies Preset.ThemeConfig,
};

export default config;
