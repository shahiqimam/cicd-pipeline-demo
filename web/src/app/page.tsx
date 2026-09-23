import { statusLabel } from '@/lib/status';

export default function Home() {
  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', padding: '4rem 2rem', maxWidth: 640, margin: '0 auto' }}>
      <h1>CI/CD Pipeline Demo</h1>
      <p>{statusLabel('ok')}</p>
      <p>This page was built, tested and deployed by Jenkins.</p>
    </main>
  );
}
