import { readdirSync, readFileSync } from "fs";
import { fileURLToPath, URL } from "url";

import { defineConfig, type Plugin } from "vite";

import tailwindcss from "@tailwindcss/vite";

import vue from "@vitejs/plugin-vue";

// Website demo build (`--mode demo`): starts from src/demo-main.ts, a real page title instead of "web", the site's favicon,
// and the item images the demo shows instead of the inventory's (web/demo/items -> demo/items). Kept out of public/ so the
// game build never ships them
const demo = (): Plugin => ({
  name: "demo",
  transformIndexHtml: {
    // Before Vite reads the entry script
    order: "pre",
    handler: (html) =>
      html
        .replace('src="/src/main.ts"', 'src="/src/demo-main.ts"')
        .replace(/<title>.*<\/title>/, "<title>Hype Vending Machine Demo | HypeScripts</title>")
        .replace(/<link rel="icon"[^>]*>/, '<link rel="icon" href="/favicon.ico" />'),
  },
  generateBundle() {
    const items = fileURLToPath(new URL("./demo/items", import.meta.url));

    for (const file of readdirSync(items)) {
      this.emitFile({ type: "asset", fileName: `demo/items/${file}`, source: readFileSync(`${items}/${file}`) });
    }
  },
});

export default defineConfig(({ mode }) => ({
  plugins: [vue(), tailwindcss(), ...(mode === "demo" ? [demo()] : [])],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: {
    fs: {
      allow: [fileURLToPath(new URL("..", import.meta.url))],
    },
  },
  build: {
    outDir: "./dist",
    emptyOutDir: true,
    // echarts alone (line + bar + canvas, already tree-shaken) is ~515 kB and can't be split further.
    // NUI loads files from disk, so the size only matters as a warning
    chunkSizeWarningLimit: 600,
    rolldownOptions: {
      // Only reports how long plugins (vue, tailwind) took; a 3s build has nothing to tune
      checks: { bundlerTimings: false },
    },
  },
  base: "./",
}));
