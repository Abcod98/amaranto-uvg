import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://amaranto-guatemala.com',
  compressHTML: true,
  build: {
    assets: '_assets'
  },
  vite: {
    css: {
      preprocessorOptions: {
        scss: {
          additionalData: `@import "src/styles/variables.scss";`
        }
      }
    }
  }
});