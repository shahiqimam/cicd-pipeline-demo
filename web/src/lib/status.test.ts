import { describe, expect, it } from 'vitest';
import { statusLabel } from './status';

describe('statusLabel', () => {
  it.each([
    ['ok', 'All systems operational'],
    ['degraded', 'Some services are slow'],
    ['down', 'Service unavailable'],
  ] as const)('maps %s', (status, label) => {
    expect(statusLabel(status)).toBe(label);
  });
});
