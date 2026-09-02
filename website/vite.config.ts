import { defineConfig } from "vite";
import { resolve } from "node:path";

/**
 * Two pages, not a single-page app.
 *
 * A download link that has to boot a router before it can show a button is the
 * wrong trade for a site whose entire job is to hand over a file. Each page is
 * static HTML that works with JavaScript switched off; the script only sharpens
 * it, by picking out the download for the visitor's own platform.
 */
export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        index: resolve(__dirname, "index.html"),
        download: resolve(__dirname, "download.html"),
      },
    },
  },
});
