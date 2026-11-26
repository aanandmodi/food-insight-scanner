const DEFAULT_ALLOWED_ORIGINS = [
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  "http://localhost:4173",
  "http://127.0.0.1:4173",
  "https://food-insight-scanner-admin.web.app",
  "https://food-insight-scanner-admin.firebaseapp.com",
];

const MAX_BODY_BYTES = 65536;

export interface AdminEdgeDeps {
  allowedOrigins?: string[];
  verifyAdminToken: (idToken: string) => Promise<{ uid: string; token: Record<string, unknown> }>;
  runAdminAction: (req: { auth: { uid: string; token: Record<string, unknown> }; data: Record<string, unknown> }) => Promise<unknown>;
}

function normalizeOrigin(origin: string): string {
  return origin.trim().replace(/\/+$/, "");
}

export function buildAllowedOrigins(extraCsv = ""): Set<string> {
  const allowed = new Set(DEFAULT_ALLOWED_ORIGINS.map(normalizeOrigin));
  for (const part of extraCsv.split(",")) {
    const clean = normalizeOrigin(part);
    if (clean) allowed.add(clean);
  }
  return allowed;
}

function corsHeaders(origin: string | null, allowed: boolean): Record<string, string> {
  const headers: Record<string, string> = {
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Vary": "Origin",
  };
  if (origin && allowed) {
    headers["Access-Control-Allow-Origin"] = origin;
    headers["Access-Control-Allow-Methods"] = "POST, OPTIONS";
    headers["Access-Control-Allow-Headers"] = "authorization, content-type";
    headers["Access-Control-Max-Age"] = "600";
  }
  return headers;
}

function errorResponse(status: number, code: string, message: string, headers: Record<string, string>): Response {
  return new Response(
    JSON.stringify({ error: { status: code, message } }),
    { status, headers: { ...headers, "Content-Type": "application/json; charset=utf-8" } },
  );
}

function mapHttpsError(error: unknown): { status: number; code: string; message: string } {
  const err = error as { code?: string; message?: string };
  const rawCode = String(err?.code || "internal").toLowerCase();
  const statusMap: Record<string, { status: number; code: string }> = {
    "unauthenticated": { status: 401, code: "UNAUTHENTICATED" },
    "permission-denied": { status: 403, code: "PERMISSION_DENIED" },
    "invalid-argument": { status: 400, code: "INVALID_ARGUMENT" },
    "not-found": { status: 404, code: "NOT_FOUND" },
    "already-exists": { status: 409, code: "ALREADY_EXISTS" },
    "failed-precondition": { status: 412, code: "FAILED_PRECONDITION" },
    "resource-exhausted": { status: 429, code: "RESOURCE_EXHAUSTED" },
    "unavailable": { status: 503, code: "UNAVAILABLE" },
  };
  const mapped = statusMap[rawCode] ?? { status: 500, code: "INTERNAL" };
  return {
    status: mapped.status,
    code: mapped.code,
    message: typeof err?.message === "string" && err.message.trim() ? err.message : "Admin request failed.",
  };
}

async function readBoundedText(req: Request, maxBytes: number): Promise<{ text: string; tooLarge: boolean }> {
  const contentLength = Number(req.headers.get("content-length") || "0");
  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    return { text: "", tooLarge: true };
  }
  if (!req.body) return { text: "", tooLarge: false };
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => {});
      return { text: "", tooLarge: true };
    }
    chunks.push(value);
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return { text: new TextDecoder().decode(merged), tooLarge: false };
}

export function createAdminEdgeHandler(deps: AdminEdgeDeps) {
  const allowedOrigins = new Set((deps.allowedOrigins ?? DEFAULT_ALLOWED_ORIGINS).map(normalizeOrigin));

  return async (req: Request): Promise<Response> => {
    const rawOrigin = req.headers.get("origin");
    const normalizedOrigin = rawOrigin ? normalizeOrigin(rawOrigin) : null;
    const originAllowed = normalizedOrigin === null || allowedOrigins.has(normalizedOrigin);
    const headers = corsHeaders(normalizedOrigin, originAllowed);

    if (!originAllowed) {
      return errorResponse(403, "PERMISSION_DENIED", "Origin not allowed.", headers);
    }

    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }
    if (req.method !== "POST") {
      return errorResponse(405, "INVALID_ARGUMENT", "Only POST requests are supported.", headers);
    }

    const authHeader = req.headers.get("authorization") ?? "";
    const bearerMatch = /^Bearer\s+(.+)$/i.exec(authHeader.trim());
    if (!bearerMatch?.[1]) {
      return errorResponse(401, "UNAUTHENTICATED", "Sign in to access the admin portal.", headers);
    }

    let verified: { uid: string; token: Record<string, unknown> };
    try {
      verified = await deps.verifyAdminToken(bearerMatch[1].trim());
    } catch {
      return errorResponse(401, "UNAUTHENTICATED", "Invalid or revoked admin session.", headers);
    }

    const { text, tooLarge } = await readBoundedText(req, MAX_BODY_BYTES);
    if (tooLarge) {
      return errorResponse(413, "INVALID_ARGUMENT", "Request payload exceeds 64 KB limit.", headers);
    }

    let parsed: unknown;
    try {
      parsed = text.trim() ? JSON.parse(text) : {};
    } catch {
      return errorResponse(400, "INVALID_ARGUMENT", "Request body must be valid JSON.", headers);
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return errorResponse(400, "INVALID_ARGUMENT", "Request body must be a JSON object.", headers);
    }

    const rawObj = parsed as Record<string, unknown>;
    const payload =
      rawObj.data && typeof rawObj.data === "object" && !Array.isArray(rawObj.data)
        ? (rawObj.data as Record<string, unknown>)
        : rawObj;

    try {
      const result = await deps.runAdminAction({
        auth: { uid: verified.uid, token: verified.token },
        data: payload,
      });
      return new Response(JSON.stringify({ result }), {
        status: 200,
        headers: { ...headers, "Content-Type": "application/json; charset=utf-8" },
      });
    } catch (error) {
      const mapped = mapHttpsError(error);
      return errorResponse(mapped.status, mapped.code, mapped.message, headers);
    }
  };
}
