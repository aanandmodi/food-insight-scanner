import { HttpsError } from 'firebase-functions/v2/https';
import { AiTask } from './aiValidation';

type Environment = Record<string, string | undefined>;
export function modelsFor(task: AiTask, env: Environment = process.env): string[] {
  const fast = env.AI_MODEL_FAST?.trim() || 'openai/gpt-oss-20b';
  const smart = env.AI_MODEL_SMART?.trim() || 'openai/gpt-oss-120b';
  const primary = ['meal', 'analysis'].includes(task) ? fast : smart;
  const fallback = env.AI_MODEL_FALLBACK?.trim() || fast;
  return [...new Set([primary, fallback])];
}

/** A single fallback for transient failures; never retry provider throttling. */
export async function requestAi(task: AiTask, apiKey: string, messages: unknown[],
  fetcher: typeof fetch = fetch, env: Environment = process.env): Promise<unknown> {
  const models = modelsFor(task, env);
  for (let index = 0; index < models.length; index++) {
    let response: Response;
    try {
      response = await fetcher('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST', headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: models[index], temperature: 0.2,
          max_completion_tokens: task === 'plan' ? 4000 : 2500,
          response_format: { type: 'json_object' }, messages }),
        signal: AbortSignal.timeout(22000),
      });
    } catch {
      if (index + 1 < models.length) continue;
      throw new HttpsError('unavailable', 'AI timed out. Please retry later.');
    }
    if (response.status === 429) {
      const raw = response.headers.get('retry-after');
      const seconds = raw && /^\d+$/.test(raw) ? Number(raw)
        : raw ? Math.ceil((Date.parse(raw) - Date.now()) / 1000) : 60;
      throw new HttpsError('resource-exhausted',
        'AI capacity is busy. Your scans and Food Fit still work. Please try again shortly.',
        { reason: 'provider', retryAfterSeconds: Number.isFinite(seconds) ? Math.max(1, Math.min(86400, seconds)) : 60 });
    }
    if (!response.ok) {
      if ((response.status >= 500 || response.status === 404) && index + 1 < models.length) continue;
      throw new HttpsError('unavailable', 'AI is temporarily unavailable.');
    }
    // Invalid JSON or incomplete output does not cause another billable request.
    const result = await response.json() as any;
    const choice = result.choices?.[0];
    if (choice?.finish_reason !== 'stop') throw new Error('Incomplete model response');
    return JSON.parse(choice.message.content);
  }
  throw new HttpsError('unavailable', 'AI is temporarily unavailable.');
}
