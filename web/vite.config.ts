import { fileURLToPath, URL } from "url";

import { defineConfig } from "vite";

import tailwindcss from "@tailwindcss/vite";

import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue(), tailwindcss()],
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
});