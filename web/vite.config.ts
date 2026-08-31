import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    // The gateway binds loopback; keep the dev server there too so a stray
    // network interface never exposes a UI that can run local commands.
    host: "127.0.0.1",
    port: 5173,
  },
  build: { outDir: "dist" },
});
