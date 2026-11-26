import { createHandler } from './handler.ts';
function assert(value: unknown, message = 'Assertion failed'): asserts value { if (!value) throw new Error(message); }
function fixture() {
  const calls: Record<string, unknown>[] = [];
  const handler = createHandler({
    authenticate: async token => { if (token !== 'valid-user') throw new Error('secret'); return { uid: 'alice', token: {} }; },
    attest: async token => { if (token !== 'valid-app') throw new Error('secret'); return { appId: 'app' }; },
    invoke: async (name, request) => { calls.push({ name, ...request }); return { barcode: '12345678' }; },
  });
  const request = (body: unknown, extra: Record<string, string> = {}) => new Request('http://localhost', {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer valid-user',
      'x-firebase-appcheck': 'valid-app', ...extra }, body: JSON.stringify(body),
  });
  return { handler, calls, request };
}
Deno.test('authenticated and attested request supplies server-derived identity', async () => {
  const { handler, calls, request } = fixture();
  const res = await handler(request({ operation: 'scanProduct', data: { barcode: '12345678', uid: 'bob' } }));
  assert(res.status === 200); assert(calls.length === 1);
  assert((calls[0].auth as { uid: string }).uid === 'alice');
});
for (const [header, value, status] of [['authorization', '', 401], ['authorization', 'Bearer forged', 401],
  ['x-firebase-appcheck', '', 403], ['x-firebase-appcheck', 'forged', 403]] as const) {
  Deno.test(`reject ${header} ${value || 'missing'} without invoking backend`, async () => {
    const { handler, calls, request } = fixture();
    assert((await handler(request({ operation: 'aiTask' }, { [header]: value }))).status === status);
    assert(calls.length === 0);
  });
}
Deno.test('unknown task and oversized UTF-8 body cannot reach backend', async () => {
  const { handler, calls, request } = fixture();
  assert((await handler(request({ operation: '__proto__' }))).status === 400);
  assert((await handler(request({ operation: 'aiTask', data: 'ह'.repeat(12000) }))).status === 413);
  assert(calls.length === 0);
});
Deno.test('provider errors never expose internal messages', async () => {
  const { request } = fixture();
  const handler = createHandler({ authenticate: async () => ({ uid: 'alice', token: {} }),
    attest: async () => ({ appId: 'app' }), invoke: async () => { throw new Error('private health data and API key'); } });
  const res = await handler(request({ operation: 'aiTask' }));
  assert(res.status === 503); assert(!(await res.text()).includes('private'));
});
Deno.test('quota errors preserve actionable status without retrying', async () => {
  const { request } = fixture(); let count = 0;
  const handler = createHandler({ authenticate: async () => ({ uid: 'alice', token: {} }),
    attest: async () => ({ appId: 'app' }), invoke: async () => { count++; throw { code: 'resource-exhausted', message: 'Daily limit reached.' }; } });
  assert((await handler(request({ operation: 'aiTask' }))).status === 429); assert(count === 1);
});
Deno.test('IP flood shield hashes client IP and blocks >30 req/min before invoking handlers', async () => {
  let invoked = false;
  let capturedHash = '';
  const handler = createHandler({
    authenticate: async () => ({ uid: 'alice', token: {} }),
    attest: async () => ({ appId: 'app' }),
    checkIpRateLimit: async (ipHash) => {
      capturedHash = ipHash;
      return { allowed: false, retryAfterSeconds: 45 };
    },
    invoke: async () => { invoked = true; return {}; },
  });
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: 'Bearer valid-user',
      'x-firebase-appcheck': 'valid-app',
      'x-forwarded-for': '198.51.100.77, 10.0.0.2',
    },
    body: JSON.stringify({ operation: 'aiTask', data: { task: 'chat', content: 'hi' } }),
  });
  const res = await handler(req);
  assert(res.status === 429);
  assert(invoked === false);
  assert(capturedHash.length === 64);
  assert(!capturedHash.includes('198.51.100.77'));
});
Deno.test('streaming aiTask requests route to invokeStream with text/event-stream headers', async () => {
  const encoder = new TextEncoder();
  const handler = createHandler({
    authenticate: async () => ({ uid: 'alice', token: {} }),
    attest: async () => ({ appId: 'app' }),
    invoke: async () => { throw new Error('Should stream instead'); },
    invokeStream: async () => new ReadableStream({
      start(controller) {
        controller.enqueue(encoder.encode('event: delta\ndata: {"text":"Hi"}\n\n'));
        controller.enqueue(encoder.encode('event: done\ndata: {"data":{"reply":"Hi"}}\n\n'));
        controller.close();
      },
    }),
  });
  const res = await handler(new Request('http://localhost', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: 'Bearer valid-user',
      'x-firebase-appcheck': 'valid-app',
    },
    body: JSON.stringify({ operation: 'aiTask', stream: true, data: { task: 'chat', content: 'Hi' } }),
  }));
  assert(res.status === 200);
  assert((res.headers.get('content-type') ?? '').includes('text/event-stream'));
  const text = await res.text();
  assert(text.includes('event: delta') && text.includes('event: done'));
});
