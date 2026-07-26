import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      include: ['assets/scripts/game/**/*.ts'],
    },
    include: ['tests/**/*.test.ts'],
  },
});
