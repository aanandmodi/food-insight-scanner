type Identity = { uid: string; token: Record<string, unknown> };
type IpRateCheckResult = { allowed: boolean; retryAfterSeconds?: number };
type Dependencies = {
  authenticate: (token: string) => Promise<Identity>;
  attest: (token: string) => Promise<{ appId: string }>;
  invoke: (name: string, request: Record<string, unknown>) => Promise<unknown>;
  invokeStream?: (name: string, request: Record<string, unknown>) => Promise<ReadableStream<Uint8Array>>;
  checkIpRateLimit?: (ipHash: string, operation: string) => Promise<IpRateCheckResult>;
  ipHashSalt?: string;
};
const status: Record<string, number> = { 'invalid-argument': 400, unauthenticated: 401,
  'permission-denied': 403, 'not-found': 404, 'failed-precondition': 412,
  'resource-exhausted': 429, unavailable: 503, 'deadline-exceeded': 504 };
const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
const sseHeaders = {
  'Content-Type': 'text/event-stream; charset=utf-8',
  'Cache-Control': 'no-cache, no-store',
  'Connection': 'keep-alive',
};
const reply = (data: unknown, code = 200) => new Response(JSON.stringify(data), { status: code, headers });

export async function extractHashedIp(request: Request, salt = 'food-insight-ip-v1'): Promise<string | undefined> {
  const raw =
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0] ??
    request.headers.get('x-real-ip') ??
    '';
  const ip = raw.trim();
  if (!ip || ip.length > 128 || !globalThis.crypto?.subtle) return undefined;
  const bytes = new TextEncoder().encode(`${salt}:${ip}`);
  const digest = await globalThis.crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

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

      const ipHash = await extractHashedIp(request, deps.ipHashSalt);
      let ipCheckedAtGateway = false;
      if (ipHash && deps.checkIpRateLimit && body.operation !== 'requestAccountDeletion') {
        const ipStatus = await deps.checkIpRateLimit(ipHash, body.operation);
        if (!ipStatus.allowed) {
          const retry = typeof ipStatus.retryAfterSeconds === 'number' && Number.isFinite(ipStatus.retryAfterSeconds)
            ? Math.max(1, Math.min(86400, Math.round(ipStatus.retryAfterSeconds)))
            : 60;
          return reply({
            error: {
              code: 'resource-exhausted',
              message: 'Too many requests from this network. Please retry shortly.',
              details: { reason: 'ip-flood', retryAfterSeconds: retry },
            },
          }, 429);
        }
        ipCheckedAtGateway = true;
      }

      const payload = {
        data: body.data ?? {},
        auth,
        app,
        ...(ipHash ? { ipHash } : {}),
        ...(ipCheckedAtGateway ? { ipCheckedAtGateway: true } : {}),
      };

      if (body.operation === 'aiTask' && body.stream === true && deps.invokeStream) {
        const stream = await deps.invokeStream(body.operation, payload);
        return new Response(stream, { status: 200, headers: sseHeaders });
      }

      const data = await deps.invoke(body.operation, payload);
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
