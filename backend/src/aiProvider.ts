import { HttpsError } from "firebase-functions/v2/https";
import { AiTask } from "./aiValidation";

type Environment = Record<string, string | undefined>;
type ProviderName = "groq" | "gemini";

export interface RequestAiOptions {
  geminiApiKey?: string;
  supabaseUrl?: string;
  serviceRoleKey?: string;
  bypassCircuit?: boolean;
}

const circuitCooldownUntil: Record<ProviderName, number> = {
  groq: 0,
  gemini: 0,
};

export function resetProviderCircuitsForTest(): void {
  circuitCooldownUntil.groq = 0;
  circuitCooldownUntil.gemini = 0;
}

export function isProviderCircuitOpen(provider: ProviderName, now = Date.now()): boolean {
  return circuitCooldownUntil[provider] > now;
}

export function modelsFor(task: AiTask, env: Environment = process.env): string[] {
  const fast = env.AI_MODEL_FAST?.trim() || "openai/gpt-oss-20b";
  const smart = env.AI_MODEL_SMART?.trim() || "openai/gpt-oss-120b";
  const primary = ["meal", "analysis", "quickReplies"].includes(task) ? fast : smart;
  const fallback = env.AI_MODEL_FALLBACK?.trim() || fast;
  return [...new Set([primary, fallback])];
}

export function geminiModelFor(task: AiTask, env: Environment = process.env): string {
  if (task === "quickReplies" || task === "meal" || task === "analysis") {
    return env.AI_MODEL_GEMINI_FAST?.trim() || env.AI_MODEL_GEMINI?.trim() || "gemini-2.5-flash";
  }
  return env.AI_MODEL_GEMINI?.trim() || "gemini-2.5-flash";
}

function boundedRetrySeconds(headerValue: string | null): number {
  const seconds =
    headerValue && /^\d+$/.test(headerValue)
      ? Number(headerValue)
      : headerValue
      ? Math.ceil((Date.parse(headerValue) - Date.now()) / 1000)
      : 60;
  return Number.isFinite(seconds) ? Math.max(1, Math.min(86400, seconds)) : 60;
}

async function reportProviderHealth(
  provider: ProviderName,
  healthy: boolean,
  status: number | null,
  cooldownSeconds: number,
  options?: RequestAiOptions,
  fetcher: typeof fetch = fetch,
): Promise<void> {
  const key = options?.serviceRoleKey?.trim();
  if (!key) return;
  const baseUrl = (options?.supabaseUrl || "https://tslcgavpkujkfexzmisk.supabase.co").replace(/\/+$/, "");
  const nowIso = new Date().toISOString();
  const cooldownIso = !healthy && cooldownSeconds > 0
    ? new Date(Date.now() + cooldownSeconds * 1000).toISOString()
    : null;
  try {
    await fetcher(`${baseUrl}/rest/v1/ai_provider_health?on_conflict=provider`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates,return=minimal",
      },
      body: JSON.stringify({
        provider,
        cooldown_until: cooldownIso,
        consecutive_failures: healthy ? 0 : 1,
        last_status: status,
        last_error_at: healthy ? null : nowIso,
        updated_at: nowIso,
      }),
      signal: AbortSignal.timeout(2500),
    });
  } catch {
    // Health telemetry must never fail a user response.
  }
}

function toGeminiPayload(task: AiTask, rawMessages: unknown[]): Record<string, unknown> {
  const messages = rawMessages.filter(
    (m): m is { role?: unknown; content?: unknown } => Boolean(m && typeof m === "object"),
  );
  const systemParts = messages
    .filter((m) => m.role === "system")
    .map((m) => ({ text: String(m.content ?? "") }))
    .filter((p) => p.text.trim().length > 0);
  const contents = messages
    .filter((m) => m.role !== "system")
    .map((m) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: String(m.content ?? "") }],
    }));

  return {
    ...(systemParts.length > 0 ? { systemInstruction: { parts: systemParts } } : {}),
    contents: contents.length > 0 ? contents : [{ role: "user", parts: [{ text: "{}" }] }],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: task === "plan" ? 4000 : 2500,
      responseMimeType: "application/json",
    },
  };
}

function parseJsonModelText(rawText: string): unknown {
  const cleaned = rawText
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  return JSON.parse(cleaned);
}

/**
 * Progressive streaming parser that extracts clean human-readable text deltas
 * inside the top-level `"reply"` JSON field without leaking raw JSON syntax.
 */
export function createJsonReplyStreamExtractor(): {
  feed: (chunk: string) => string;
  rawText: () => string;
} {
  let fullRaw = "";
  let depth = 0;
  let inString = false;
  let escaping = false;
  let unicodeLeft = 0;
  let unicodeBuf = "";
  let stringKind: "none" | "key" | "otherValue" | "replyValue" = "none";
  let currentKey = "";
  let expectKeyAtDepth1 = false;
  let lastKeyAtDepth1 = "";
  let expectingColon = false;
  let expectingValue = false;
  let doneReply = false;

  const feed = (chunk: string): string => {
    let deltaOut = "";
    for (let i = 0; i < chunk.length; i++) {
      const ch = chunk[i];
      fullRaw += ch;

      if (!inString) {
        if (ch === "{") {
          depth++;
          expectKeyAtDepth1 = depth === 1;
          expectingColon = false;
          expectingValue = false;
        } else if (ch === "}") {
          depth = Math.max(0, depth - 1);
          expectingColon = false;
          expectingValue = false;
        } else if (ch === "[") {
          depth++;
        } else if (ch === "]") {
          depth = Math.max(0, depth - 1);
        } else if (ch === ":" && depth === 1 && expectingColon) {
          expectingColon = false;
          expectingValue = true;
        } else if (ch === "," && depth === 1) {
          expectKeyAtDepth1 = true;
          expectingValue = false;
          expectingColon = false;
        } else if (ch === '"') {
          inString = true;
          escaping = false;
          if (depth === 1 && expectKeyAtDepth1) {
            stringKind = "key";
            currentKey = "";
            expectKeyAtDepth1 = false;
          } else if (depth === 1 && expectingValue && lastKeyAtDepth1 === "reply" && !doneReply) {
            stringKind = "replyValue";
            expectingValue = false;
          } else {
            stringKind = "otherValue";
            expectingValue = false;
          }
        } else if (!/\s/.test(ch) && depth === 1 && expectingValue) {
          // Primitive/non-string value (number/boolean/null)
          expectingValue = false;
        }
        continue;
      }

      if (unicodeLeft > 0) {
        unicodeBuf += ch;
        unicodeLeft--;
        if (unicodeLeft === 0) {
          const code = Number.parseInt(unicodeBuf, 16);
          const decoded = Number.isFinite(code) ? String.fromCharCode(code) : "";
          if (stringKind === "key") currentKey += decoded;
          else if (stringKind === "replyValue") deltaOut += decoded;
          unicodeBuf = "";
        }
        continue;
      }

      if (escaping) {
        escaping = false;
        let decoded = ch;
        if (ch === "n") decoded = "\n";
        else if (ch === "r") decoded = "\r";
        else if (ch === "t") decoded = "\t";
        else if (ch === "b") decoded = "\b";
        else if (ch === "f") decoded = "\f";
        else if (ch === "u") {
          unicodeLeft = 4;
          unicodeBuf = "";
          continue;
        }
        if (stringKind === "key") currentKey += decoded;
        else if (stringKind === "replyValue") deltaOut += decoded;
        continue;
      }

      if (ch === "\\") {
        escaping = true;
        continue;
      }

      if (ch === '"') {
        inString = false;
        if (stringKind === "key") {
          lastKeyAtDepth1 = currentKey;
          expectingColon = true;
        } else if (stringKind === "replyValue") {
          doneReply = true;
        }
        stringKind = "none";
        continue;
      }

      if (stringKind === "key") currentKey += ch;
      else if (stringKind === "replyValue") deltaOut += ch;
    }
    return deltaOut;
  };

  return {
    feed,
    rawText: () => fullRaw,
  };
}

async function consumeUpstreamSse(
  body: ReadableStream<Uint8Array>,
  extractContent: (parsedEvent: any) => { token?: string; stopReason?: string },
  onDelta: (token: string) => void,
): Promise<string> {
  const extractor = createJsonReplyStreamExtractor();
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let stopReason = "";

  const processLines = (lines: string[]) => {
    for (const rawLine of lines) {
      const line = rawLine.trim();
      if (!line.startsWith("data:")) continue;
      const payload = line.slice(5).trim();
      if (!payload || payload === "[DONE]") continue;
      let parsed: any;
      try {
        parsed = JSON.parse(payload);
      } catch {
        continue;
      }
      const { token, stopReason: reason } = extractContent(parsed);
      if (reason) stopReason = reason;
      if (token) {
        const readableDelta = extractor.feed(token);
        if (readableDelta) onDelta(readableDelta);
      }
    }
  };

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const parts = buffer.split(/\r?\n/);
    buffer = parts.pop() ?? "";
    processLines(parts);
  }
  const tail = decoder.decode();
  if (tail) buffer += tail;
  if (buffer.trim()) processLines(buffer.split(/\r?\n/));

  if (stopReason && stopReason !== "stop" && stopReason !== "STOP") {
    throw new Error("Incomplete model response");
  }
  return extractor.rawText();
}

async function callGeminiFlash(
  task: AiTask,
  geminiKey: string,
  messages: unknown[],
  fetcher: typeof fetch,
  env: Environment,
  options?: RequestAiOptions,
  onDelta?: (token: string) => void,
): Promise<unknown> {
  const model = geminiModelFor(task, env);
  const endpoint = onDelta
    ? `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:streamGenerateContent?alt=sse`
    : `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;

  let response: Response;
  try {
    response = await fetcher(endpoint, {
      method: "POST",
      headers: {
        "x-goog-api-key": geminiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(toGeminiPayload(task, messages)),
      signal: AbortSignal.timeout(22000),
    });
  } catch {
    circuitCooldownUntil.gemini = Date.now() + 30000;
    void reportProviderHealth("gemini", false, 504, 30, options, fetcher);
    throw new HttpsError("unavailable", "AI timed out. Please retry later.");
  }

  if (response.status === 429) {
    const retryAfterSeconds = boundedRetrySeconds(response.headers.get("retry-after"));
    circuitCooldownUntil.gemini = Date.now() + Math.min(retryAfterSeconds, 300) * 1000;
    void reportProviderHealth("gemini", false, 429, Math.min(retryAfterSeconds, 300), options, fetcher);
    throw new HttpsError(
      "resource-exhausted",
      "AI capacity is busy. Your scans and Food Fit still work. Please try again shortly.",
      { reason: "provider", retryAfterSeconds },
    );
  }

  if (!response.ok) {
    if (response.status >= 500) {
      circuitCooldownUntil.gemini = Date.now() + 30000;
      void reportProviderHealth("gemini", false, response.status, 30, options, fetcher);
    }
    throw new HttpsError("unavailable", "AI is temporarily unavailable.");
  }

  if (onDelta && response.body) {
    const rawJson = await consumeUpstreamSse(
      response.body,
      (ev) => {
        const cand = ev?.candidates?.[0];
        const parts = Array.isArray(cand?.content?.parts) ? cand.content.parts : [];
        const text = parts.map((p: any) => String(p?.text ?? "")).join("");
        return {
          token: text || undefined,
          stopReason: cand?.finishReason ? String(cand.finishReason) : undefined,
        };
      },
      onDelta,
    );
    if (!rawJson.trim()) throw new Error("Empty model response");
    circuitCooldownUntil.gemini = 0;
    void reportProviderHealth("gemini", true, 200, 0, options, fetcher);
    return parseJsonModelText(rawJson);
  }

  const payload = (await response.json()) as any;
  const candidate = payload?.candidates?.[0];
  const finishReason = String(candidate?.finishReason ?? "").toUpperCase();
  if (finishReason && finishReason !== "STOP") {
    throw new Error("Incomplete model response");
  }
  const parts = Array.isArray(candidate?.content?.parts) ? candidate.content.parts : [];
  const text = parts.map((part: any) => String(part?.text ?? "")).join("");
  if (!text.trim()) throw new Error("Empty model response");

  circuitCooldownUntil.gemini = 0;
  void reportProviderHealth("gemini", true, 200, 0, options, fetcher);
  return parseJsonModelText(text);
}

/**
 * Primary Groq execution with per-model transient fallback, plus seamless automatic
 * failover to Google Gemini Flash Free API key (`GEMINI_API_KEY`) on Groq 429/5xx/timeout.
 */
export async function requestAi(
  task: AiTask,
  apiKey: string,
  messages: unknown[],
  fetcher: typeof fetch = fetch,
  env: Environment = process.env,
  options?: RequestAiOptions,
): Promise<unknown> {
  return executeAiRequest(task, apiKey, messages, fetcher, env, options);
}

/** Streaming version emitting human-readable `"reply"` deltas while retaining full JSON + safety validation. */
export async function requestAiStream(
  task: AiTask,
  apiKey: string,
  messages: unknown[],
  onDelta: (token: string) => void,
  fetcher: typeof fetch = fetch,
  env: Environment = process.env,
  options?: RequestAiOptions,
): Promise<unknown> {
  return executeAiRequest(task, apiKey, messages, fetcher, env, options, onDelta);
}

async function executeAiRequest(
  task: AiTask,
  apiKey: string,
  messages: unknown[],
  fetcher: typeof fetch = fetch,
  env: Environment = process.env,
  options?: RequestAiOptions,
  onDelta?: (token: string) => void,
): Promise<unknown> {
  const geminiKey = options?.geminiApiKey?.trim() || env.GEMINI_API_KEY?.trim() || "";
  const hasGeminiFallback = geminiKey.length > 0;
  const groqKey = apiKey?.trim() || "";
  const shouldTryGroq =
    groqKey.length > 0 &&
    (options?.bypassCircuit || !hasGeminiFallback || !isProviderCircuitOpen("groq"));

  let groqFailure: HttpsError | null = null;
  let emittedAnyDelta = false;
  const emitDelta = onDelta
    ? (text: string) => {
        emittedAnyDelta = true;
        onDelta(text);
      }
    : undefined;

  if (shouldTryGroq) {
    const models = modelsFor(task, env);
    for (let index = 0; index < models.length; index++) {
      let response: Response;
      try {
        response = await fetcher("https://api.groq.com/openai/v1/chat/completions", {
          method: "POST",
          headers: { Authorization: `Bearer ${groqKey}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            model: models[index],
            temperature: 0.2,
            max_completion_tokens: task === "plan" ? 4000 : 2500,
            response_format: { type: "json_object" },
            ...(emitDelta ? { stream: true } : {}),
            messages,
          }),
          signal: AbortSignal.timeout(22000),
        });
      } catch {
        if (index + 1 < models.length) continue;
        circuitCooldownUntil.groq = Date.now() + 30000;
        void reportProviderHealth("groq", false, 504, 30, options, fetcher);
        groqFailure = new HttpsError("unavailable", "AI timed out. Please retry later.");
        break;
      }

      if (response.status === 429) {
        const retryAfterSeconds = boundedRetrySeconds(response.headers.get("retry-after"));
        circuitCooldownUntil.groq = Date.now() + Math.min(retryAfterSeconds, 300) * 1000;
        void reportProviderHealth("groq", false, 429, Math.min(retryAfterSeconds, 300), options, fetcher);
        groqFailure = new HttpsError(
          "resource-exhausted",
          "AI capacity is busy. Your scans and Food Fit still work. Please try again shortly.",
          { reason: "provider", retryAfterSeconds },
        );
        break;
      }

      if (!response.ok) {
        if ((response.status >= 500 || response.status === 404) && index + 1 < models.length) continue;
        if (response.status >= 500) {
          circuitCooldownUntil.groq = Date.now() + 30000;
          void reportProviderHealth("groq", false, response.status, 30, options, fetcher);
        }
        groqFailure = new HttpsError("unavailable", "AI is temporarily unavailable.");
        break;
      }

      if (emitDelta && response.body) {
        const rawJson = await consumeUpstreamSse(
          response.body,
          (ev) => {
            const choice = ev?.choices?.[0];
            return {
              token: typeof choice?.delta?.content === "string" ? choice.delta.content : undefined,
              stopReason: choice?.finish_reason ? String(choice.finish_reason) : undefined,
            };
          },
          emitDelta,
        );
        circuitCooldownUntil.groq = 0;
        void reportProviderHealth("groq", true, 200, 0, options, fetcher);
        return parseJsonModelText(rawJson);
      }

      // Invalid JSON or incomplete output does not trigger another billable request.
      const result = (await response.json()) as any;
      const choice = result.choices?.[0];
      if (choice?.finish_reason !== "stop") throw new Error("Incomplete model response");
      circuitCooldownUntil.groq = 0;
      void reportProviderHealth("groq", true, 200, 0, options, fetcher);
      return JSON.parse(choice.message.content);
    }
  }

  if (!emittedAnyDelta && hasGeminiFallback && (options?.bypassCircuit || !isProviderCircuitOpen("gemini"))) {
    return callGeminiFlash(task, geminiKey, messages, fetcher, env, options, emitDelta);
  }

  if (groqFailure) throw groqFailure;
  throw new HttpsError("unavailable", "AI is temporarily unavailable.");
}
