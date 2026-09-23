import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    include: ['src/**/*.test.ts'],
    reporters: ['default', 'junit'],
    outputFile: { junit: './junit.xml' },
  },
});
