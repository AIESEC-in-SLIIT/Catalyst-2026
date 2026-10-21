import { defineConfig } from 'vite';
import { resolve } from 'node:path';
export default defineConfig({
  base: './',
  server: { host: '127.0.0.1', port: 5173 },
  build: { rolldownOptions: {
    // This is a browser-only application; React server-component directives do not apply.
    onwarn(warning, warn) {
      if (warning.code === 'MODULE_LEVEL_DIRECTIVE' && warning.message.includes('use client')) return;
      warn(warning);
    },
    input: {
    main: resolve(import.meta.dirname, 'index.html'),
    marketplace: resolve(import.meta.dirname, 'marketplace/index.html'),
  } } },
});
