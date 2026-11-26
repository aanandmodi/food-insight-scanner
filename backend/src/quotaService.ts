import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { AiTask, limits } from "./aiValidation";

export const GUEST_DAILY_LIMITS: Record<AiTask, number> = {
  chat: 3,
  meal: 3,
  plan: 1,
  analysis: 3,
  macros: 0,
  quickReplies: 5,
};

export interface QuotaCheckInput {
  uid: string;
  task: AiTask;
  isGuest: boolean;
  configuredLimit?: unknown;
  ipHash?: string | null;
  ipPerMinuteLimit?: unknown;
  supabaseUrl?: string;
  serviceRoleKey?: string;
  fetcher?: typeof fetch;
}

export interface QuotaCheckResult {
  backend: "postgres" | "firestore";
  used: number;
  limit: number;
  remaining: number;
}

export async function sha256Hex(raw: string): Promise<string> {
  const subtle = globalThis.crypto?.subtle;
  if (!subtle) return "";
  const bytes = new TextEncoder().encode(raw);
  const digest = await subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function hashClientIp(
  rawIp: string | undefined | null,
  salt = process.env.IP_HASH_SALT || "food-insight-ip-v1",
): Promise<string | null> {
  const normalized = (rawIp ?? "").split(",")[0]?.trim();
  if (!normalized || normalized.length > 128) return null;
  const hex = await sha256Hex(`${salt}:${normalized}`);
  return hex || null;
}

function throwQuotaRejected(payload: {
  reason?: unknown;
  retryAfterSeconds?: unknown;
}): never {
  const reason = String(payload.reason ?? "daily-quota");
  const retry = typeof payload.retryAfterSeconds === "number" && Number.isFinite(payload.retryAfterSeconds)
    ? Math.max(1, Math.min(86400, Math.round(payload.retryAfterSeconds)))
    : undefined;

  if (reason === "ip-flood") {
    throw new HttpsError(
      "resource-exhausted",
      "Too many AI requests from this connection. Your barcode scans and logs still work. Please retry shortly.",
      { reason: "ip-flood", retryAfterSeconds: retry ?? 60 },
    );
  }
  if (reason === "burst") {
    throw new HttpsError(
      "resource-exhausted",
      "Please wait a moment before sending another AI request.",
      { reason: "burst", retryAfterSeconds: retry ?? 2 },
    );
  }
  throw new HttpsError(
    "resource-exhausted",
    "Daily AI limit reached for your plan. Barcode scanning and manual meal logs remain available.",
    { reason: "daily-quota", ...(retry !== undefined ? { retryAfterSeconds: retry } : {}) },
  );
}

/**
 * Primary rate-limiter using PostgreSQL `check_and_consume_ai_quota` RPC
 * (with Firestore per-user fallback only when Supabase credentials are absent).
 * Never imposes a global 200/day kill-switch across unrelated users.
 */
export async function consumeAiQuota(input: QuotaCheckInput): Promise<QuotaCheckResult> {
  const configuredDaily =
    typeof input.configuredLimit === "number" &&
    Number.isInteger(input.configuredLimit) &&
    input.configuredLimit >= 0 &&
    input.configuredLimit <= 500
      ? input.configuredLimit
      : null;

  const ipLimit =
    typeof input.ipPerMinuteLimit === "number" &&
    Number.isInteger(input.ipPerMinuteLimit) &&
    input.ipPerMinuteLimit >= 1 &&
    input.ipPerMinuteLimit <= 500
      ? input.ipPerMinuteLimit
      : 30;

  const key = input.serviceRoleKey?.trim();
  const baseUrl = (input.supabaseUrl || "https://tslcgavpkujkfexzmisk.supabase.co").replace(/\/+$/, "");
  const fetcher = input.fetcher ?? fetch;

  if (key) {
    let response: Response | null = null;
    try {
      response = await fetcher(`${baseUrl}/rest/v1/rpc/check_and_consume_ai_quota`, {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_user_id: input.uid,
          p_task: input.task,
          p_is_guest: input.isGuest,
          p_daily_limit: configuredDaily,
          p_cooldown_seconds: null,
          p_ip_hash: input.ipHash || null,
          p_ip_per_minute_limit: ipLimit,
        }),
        signal: AbortSignal.timeout(4000),
      });
    } catch {
      response = null;
    }

    if (response && response.ok) {
      const rpcResult = (await response.json()) as Record<string, any>;
      if (rpcResult && rpcResult.allowed === false) {
        throwQuotaRejected(rpcResult);
      }
      if (rpcResult && rpcResult.allowed === true) {
        const limit = Number(rpcResult.limit) || 0;
        const used = Number(rpcResult.used) || 0;
        return {
          backend: "postgres",
          used,
          limit,
          remaining: Math.max(0, limit - used),
        };
      }
    }
  }

  // Fallback for local/Firestore-only deployments: strictly per-user limits (no global kill-switch).
  const db = getFirestore();
  const baseLimit = configuredDaily ?? limits[input.task];
  const dailyLimit = input.isGuest
    ? Math.min(baseLimit, GUEST_DAILY_LIMITS[input.task])
    : baseLimit;
  const cooldownMs = input.isGuest && input.task !== "quickReplies" ? 30000 : 2000;
  const day = new Date().toISOString().slice(0, 10);
  const quotaRef = db.doc(`users/${input.uid}/aiUsage/current`);

  let usedAfter = 0;
  await db.runTransaction(async (transaction) => {
    const data = (await transaction.get(quotaRef)).data() ?? {};
    const count = data.day === day ? Number(data[input.task]) || 0 : 0;
    const stampKey = `lastAt_${input.task}`;
    const legacyStamp = input.task === "quickReplies" ? data.lastQuickReplyAt : data.lastRequestAt;
    const lastRequestAt = Number(data[stampKey] ?? (input.isGuest ? legacyStamp : 0)) || 0;

    if (lastRequestAt > 0 && Date.now() - lastRequestAt < cooldownMs) {
      throwQuotaRejected({
        reason: "burst",
        retryAfterSeconds: Math.ceil((cooldownMs - (Date.now() - lastRequestAt)) / 1000),
      });
    }
    if (count >= dailyLimit) {
      throwQuotaRejected({ reason: "daily-quota" });
    }
    usedAfter = count + 1;
    transaction.set(quotaRef, {
      ...(data.day === day ? data : {}),
      day,
      [input.task]: usedAfter,
      [stampKey]: Date.now(),
    });
  });

  return {
    backend: "firestore",
    used: usedAfter,
    limit: dailyLimit,
    remaining: Math.max(0, dailyLimit - usedAfter),
  };
}
