import { defineConfig } from 'vite';
import { existsSync, readdirSync, unlinkSync } from 'fs';
import { resolve, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

/** Remove prior hashed assets so docs/dashboard/assets does not accumulate orphans. */
function cleanDashboardAssets() {
  return {
    name: 'clean-dashboard-assets',
    buildStart() {
      const assetsDir = resolve(__dirname, '../docs/dashboard/assets');
      if (!existsSync(assetsDir)) return;
      for (const f of readdirSync(assetsDir)) {
        try {
          unlinkSync(join(assetsDir, f));
        } catch (_) {
          /* ignore */
        }
      }
    },
  };
}

export default defineConfig({
  base: './',
  plugins: [cleanDashboardAssets()],
  build: {
    outDir: '../docs/dashboard',
    emptyOutDir: false,
  },
});
