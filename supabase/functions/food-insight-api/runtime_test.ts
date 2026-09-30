import { initializeApp } from 'firebase-admin/app';
import { initializeFirestore } from 'firebase-admin/firestore';
Deno.test('shared Firebase handlers load in Deno and reject missing authentication', async () => {
  const app = initializeApp({ projectId: 'demo-food-insight' });
  initializeFirestore(app, { preferRest: true });
  const handlers = await import('./backend.js');
  for (const handler of [handlers.scanProduct, handlers.aiTask, handlers.requestAccountDeletion]) {
    let rejected = false;
    try { await handler.run({ data: {} } as Parameters<typeof handler.run>[0]); }
    catch (error) { rejected = (error as { code: string }).code === 'unauthenticated'; }
    if (!rejected) throw new Error('Unauthenticated handler was not rejected');
  }
});
