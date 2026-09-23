import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    globals: true,
    root: './',
    include: ['**/*.spec.ts'],
    // default = console output, junit = report Jenkins publishes
    reporters: ['default', 'junit'],
    outputFile: { junit: './junit.xml' },
    coverage: {
      provider: 'v8',
      include: ['src/**/*.ts'],
      exclude: ['src/main.ts', 'src/**/*.spec.ts'],
      reporter: ['text', 'html', 'cobertura'],
      // The build fails if coverage drops below these numbers
      thresholds: { lines: 80, functions: 80, statements: 80, branches: 50 },
    },
  },
});
