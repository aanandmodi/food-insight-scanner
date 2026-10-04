type Identity = { uid: string; token: Record<string, unknown> };
type Dependencies = {
  authenticate: (token: string) => Promise<Identity>;
  attest: (token: string) => Promise<{ appId: string }>;
  invoke: (name: string, request: Record<string, unknown>) => Promise<unknown>;
};
const status: Record<string, number> = { 'invalid-argument': 400, unauthenticated: 401,
  'permission-denied': 403, 'not-found': 404, 'failed-precondition': 412,
  'resource-exhausted': 429, unavailable: 503, 'deadline-exceeded': 504 };
const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
const reply = (data: unknown, code = 200) => new Response(JSON.stringify(data), { status: code, headers });

export function createHandler(deps: Dependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return reply({ error: { code: 'invalid-argument', message: 'POST required.' } }, 405);
    try {
      if (!request.headers.get('content-type')?.startsWith('application/json')) return reply({ error: { code: 'invalid-argument' } }, 415);
      // Bound actual streamed bytes, not a caller-controlled Content-Length.
      const reader = request.body?.getReader();
      if (!reader) return reply({ error: { code: 'invalid-argument' } }, 400);
      const chunks: Uint8Array[] = [];
      let size = 0;
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 33000) { await reader.cancel(); return reply({ error: { code: 'invalid-argument', message: 'Request too large.' } }, 413); }
        chunks.push(value);
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
      let body;
      try { body = JSON.parse(new TextDecoder().decode(bytes)); }
      catch { return reply({ error: { code: 'invalid-argument' } }, 400); }
      if (!body || !['scanProduct', 'aiTask', 'alternatives', 'requestAccountDeletion'].includes(body.operation)) return reply({ error: { code: 'invalid-argument' } }, 400);
      const bearer = request.headers.get('authorization')?.match(/^Bearer (\S+)$/)?.[1];
      if (!bearer) return reply({ error: { code: 'unauthenticated' } }, 401);
      let auth;
      try { auth = await deps.authenticate(bearer); }
      catch { return reply({ error: { code: 'unauthenticated', message: 'Sign in again.' } }, 401); }
      let app;
      try { app = await deps.attest(request.headers.get('x-firebase-appcheck') ?? ''); }
      catch { return reply({ error: { code: 'permission-denied', message: 'This installation could not be verified.' } }, 403); }
      const data = await deps.invoke(body.operation, { data: body.data ?? {}, auth, app });
      return reply({ data });
    } catch (error) {
      const safe = error as { code?: string; message?: string; details?: {retryAfterSeconds?:number} };
      const code = safe.code && status[safe.code] ? safe.code : 'unavailable';
      const retry = safe.details?.retryAfterSeconds;
      return reply({ error: { code, message: code === 'unavailable' ? 'Service temporarily unavailable.' : safe.message,
        ...(code === 'resource-exhausted' && typeof retry === 'number' && Number.isFinite(retry)
          ? {details:{retryAfterSeconds:Math.max(1,Math.min(86400,retry))}} : {}) } }, status[code]);
    }
  };
}
