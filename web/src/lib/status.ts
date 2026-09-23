export type ServiceStatus = 'ok' | 'degraded' | 'down';

export function statusLabel(status: ServiceStatus): string {
  switch (status) {
    case 'ok':
      return 'All systems operational';
    case 'degraded':
      return 'Some services are slow';
    case 'down':
      return 'Service unavailable';
  }
}
