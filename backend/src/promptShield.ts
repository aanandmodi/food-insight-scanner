import { AiTask } from "./aiValidation";

export type AbuseCategory =
  | "delimiter_escape"
  | "role_hijack"
  | "prompt_extraction"
  | "safety_override"
  | "off_topic_abuse"
  | "moderation_unsafe"
  | "unsafe_output";

export type AbuseSeverity = "low" | "medium" | "high";

export interface PromptShieldMatch {
  blocked: boolean;
  requiresModeration: boolean;
  category: AbuseCategory;
  severity: AbuseSeverity;
  ruleId: string;
  snippet: string;
}

export interface AbuseEventRecord {
  userId: string;
  task: AiTask;
  category: AbuseCategory;
  severity: AbuseSeverity;
  ruleId: string;
  snippet: string;
}

const ZERO_WIDTH_AND_BIDI = /[\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]/g;
const CONTROL_CHARS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g;

/**
 * Layer 1: Strip invisible Unicode tricks (zero-width joiners, RTL overrides)
 * and control characters while preserving normal newlines, tabs, and Indic scripts.
 */
export function sanitizeUntrustedText(raw: string, maxLength = 16000): string {
  return raw
    .replace(ZERO_WIDTH_AND_BIDI, "")
    .replace(CONTROL_CHARS, "")
    .replace(/\r\n?/g, "\n")
    .trim()
    .slice(0, maxLength);
}

/**
 * Layer 3 helper: neutralize attempts to close/open trusted prompt delimiters
 * inside serialized untrusted background JSON.
 */
export function escapeDelimiters(raw: string): string {
  return sanitizeUntrustedText(raw, raw.length)
    .replace(/END_UNTRUSTED_DATA/gi, "[end-data-marker]")
    .replace(/UNTRUSTED_DATA/gi, "[data-marker]")
    .replace(/<\|im_(?:start|end)\|>/gi, "[role-marker]")
    .replace(/\[\/?INST\]/gi, "[inst-marker]");
}

interface HeuristicRule {
  ruleId: string;
  category: AbuseCategory;
  severity: AbuseSeverity;
  requiresModeration: boolean;
  blocked: boolean;
  pattern: RegExp;
}

const RULES: HeuristicRule[] = [
  {
    ruleId: "delim-escape",
    category: "delimiter_escape",
    severity: "high",
    requiresModeration: false,
    blocked: true,
    pattern: /(?:END_UNTRUSTED_DATA|<\|im_start\|>\s*system|<\|system\|>|\[INST\]|\[\s*SYSTEM\s*\])/i,
  },
  {
    ruleId: "role-override",
    category: "role_hijack",
    severity: "high",
    requiresModeration: false,
    blocked: true,
    pattern: /(?:ignore|disregard|forget|override|bypass)\s+(?:all\s+|any\s+|your\s+|the\s+)?(?:previous|prior|above|system|developer|safety)\s+(?:instructions?|rules?|prompt|constraints?|directives?)/i,
  },
  {
    ruleId: "jailbreak-persona",
    category: "role_hijack",
    severity: "high",
    requiresModeration: true,
    blocked: true,
    pattern: /(?:you\s+are\s+now\s+(?:DAN|an?\s+unrestricted|in\s+developer\s+mode|jailbroken)|enable\s+developer\s+mode|act\s+as\s+(?:a\s+hacker|an?\s+unfiltered\s+ai)|new\s+system\s+prompt\s*:)/i,
  },
  {
    ruleId: "prompt-extract",
    category: "prompt_extraction",
    severity: "high",
    requiresModeration: false,
    blocked: true,
    pattern: /(?:reveal|show|print|output|repeat|dump|leak|tell\s+me)\s+(?:your\s+)?(?:exact\s+|full\s+|hidden\s+)?(?:system\s+prompt|developer\s+prompt|hidden\s+instructions?|secret\s+instructions?|api[_\s-]?key)/i,
  },
  {
    ruleId: "allergy-safety-bypass",
    category: "safety_override",
    severity: "high",
    requiresModeration: true,
    blocked: true,
    pattern: /(?:ignore|override|hide|omit|skip|pretend\s+i\s+don'?t\s+have)\s+(?:my\s+|the\s+|user'?s\s+)?(?:allerg(?:y|ies)|anaphylaxis|gluten|celiac|peanut|dietary\s+restrictions?)/i,
  },
  {
    ruleId: "off-topic-code-abuse",
    category: "off_topic_abuse",
    severity: "medium",
    requiresModeration: true,
    blocked: true,
    pattern: /(?:write\s+(?:a\s+)?(?:python|bash|powershell|sql|exploit|malware|ransomware|phishing)\b|sql\s+injection|\bdrop\s+table\b|\brm\s+-rf\b|<\s*script\b)/i,
  },
  {
    ruleId: "self-harm-starvation",
    category: "moderation_unsafe",
    severity: "medium",
    requiresModeration: true,
    blocked: true,
    pattern: /(?:how\s+to\s+starve\s+myself|pro[\s-]?ana\s+tips|under\s+400\s+calories\s+daily\s+plan|force\s+myself\s+to\s+vomit)/i,
  },
];

function collectStrings(value: unknown, out: string[] = [], depth = 0): string[] {
  if (depth > 6 || out.length >= 80) return out;
  if (typeof value === "string") {
    const cleaned = sanitizeUntrustedText(value, 16000);
    if (cleaned) out.push(cleaned);
    return out;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectStrings(item, out, depth + 1);
    return out;
  }
  if (value && typeof value === "object") {
    for (const v of Object.values(value as Record<string, unknown>)) {
      collectStrings(v, out, depth + 1);
    }
  }
  return out;
}

/**
 * Layer 2a: Fast deterministic prompt-injection & abuse detector across all
 * untrusted caller inputs (including message, history, and custom product fields).
 */
export function inspectPromptShield(inputs: unknown[]): PromptShieldMatch | null {
  const strings = inputs.flatMap((item) => collectStrings(item));
  for (const text of strings) {
    // Also check NFKC normalized text so homoglyph variations don't evade heuristics.
    const normalized = text.normalize("NFKC");
    for (const rule of RULES) {
      const match = rule.pattern.exec(normalized);
      if (match) {
        return {
          blocked: rule.blocked,
          requiresModeration: rule.requiresModeration,
          category: rule.category,
          severity: rule.severity,
          ruleId: rule.ruleId,
          snippet: match[0].slice(0, 120),
        };
      }
    }
  }
  return null;
}

/**
 * Layer 2b: Optional Groq moderation model check (`meta-llama/llama-guard-4-12b`)
 * when enabled via env `AI_MODERATION_ENABLED=true`.
 */
export async function moderateWithLlamaGuard(
  userText: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  env: Record<string, string | undefined> = process.env,
): Promise<{ safe: boolean; reason?: string }> {
  if (env.AI_MODERATION_ENABLED !== "true" || !apiKey) {
    return { safe: true };
  }
  const cleaned = sanitizeUntrustedText(userText, 2000);
  if (!cleaned) return { safe: true };

  const model = env.AI_MODEL_GUARD?.trim() || "meta-llama/llama-guard-4-12b";
  try {
    const response = await fetcher("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0,
        max_completion_tokens: 32,
        messages: [{ role: "user", content: cleaned }],
      }),
      signal: AbortSignal.timeout(4000),
    });
    if (!response.ok) return { safe: true };
    const payload = await response.json() as any;
    const verdict = String(payload?.choices?.[0]?.message?.content ?? "").trim().toLowerCase();
    if (verdict.startsWith("unsafe")) {
      return { safe: false, reason: verdict.slice(0, 64) };
    }
    return { safe: true };
  } catch {
    return { safe: true };
  }
}

/**
 * Layer 5: Best-effort non-PII abuse telemetry writer to Supabase `ai_abuse_events`.
 * Never blocks user error response if telemetry insert fails.
 */
export async function recordAbuseEvent(
  event: AbuseEventRecord,
  options: {
    supabaseUrl?: string;
    serviceRoleKey?: string;
    fetcher?: typeof fetch;
  } = {},
): Promise<void> {
  const key = options.serviceRoleKey?.trim();
  const baseUrl = (options.supabaseUrl || "https://tslcgavpkujkfexzmisk.supabase.co").replace(/\/+$/, "");
  if (!key) return;
  const fetcher = options.fetcher ?? fetch;
  try {
    await fetcher(`${baseUrl}/rest/v1/ai_abuse_events`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        user_id: event.userId.slice(0, 128),
        task: String(event.task).slice(0, 32),
        category: event.category.slice(0, 64),
        severity: event.severity,
        rule_id: event.ruleId.slice(0, 64),
        snippet: sanitizeUntrustedText(event.snippet, 160),
      }),
      signal: AbortSignal.timeout(4000),
    });
  } catch {
    // Telemetry is best-effort and must never crash request handling.
  }
}
