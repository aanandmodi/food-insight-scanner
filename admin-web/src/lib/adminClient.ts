import { firebaseAuth } from './firebase';
import type { FeatureFlags } from './types';

export const ADMIN_EDGE_URL = (
  import.meta.env?.VITE_ADMIN_EDGE_URL ??
  'https://tslcgavpkujkfexzmisk.supabase.co/functions/v1/food-insight-admin'
).trim();

export class AdminApiError extends Error {
  status: number;
  code: string;

  constructor(message: string, status = 500, code = 'INTERNAL') {
    super(message);
    this.name = 'AdminApiError';
    this.status = status;
    this.code = code;
  }
}

export interface AdminCallDeps {
  edgeUrl?: string;
  getToken?: () => Promise<string | null>;
  fetcher?: typeof fetch;
}

export async function callAdminAction<T = Record<string, unknown>>(
  action: string,
  payload: Record<string, unknown> = {},
  deps: AdminCallDeps = {},
): Promise<T> {
  const token = deps.getToken
    ? await deps.getToken()
    : await firebaseAuth?.currentUser?.getIdToken();

  if (!token) {
    throw new AdminApiError('Sign in as a verified administrator first.', 401, 'UNAUTHENTICATED');
  }

  const fetcher = deps.fetcher ?? fetch;
  const response = await fetcher(deps.edgeUrl ?? ADMIN_EDGE_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ action, ...payload }),
  });

  const text = await response.text();
  let parsed: Record<string, unknown> = {};
  try {
    parsed = text ? (JSON.parse(text) as Record<string, unknown>) : {};
  } catch {
    throw new AdminApiError(
      `Unexpected server response (${response.status}).`,
      response.status,
      'INVALID_RESPONSE',
    );
  }

  if (!response.ok || parsed.error) {
    const err = (parsed.error as Record<string, unknown> | undefined) ?? {};
    throw new AdminApiError(
      typeof err.message === 'string' && err.message ? err.message : `Request failed (${response.status}).`,
      response.status,
      typeof err.status === 'string' ? err.status : 'ERROR',
    );
  }

  return (parsed.result ?? parsed) as T;
}

/**
 * Computes only modified flag keys so admin saves produce minimal, auditable diffs.
 */
export function buildFlagPatchDiff(
  baseline: FeatureFlags,
  draft: FeatureFlags,
): Record<string, unknown> {
  const patch: Record<string, unknown> = {};
  const scalarKeys: Array<keyof FeatureFlags> = [
    'aiEnabled',
    'aiChatEnabled',
    'mealPlannerEnabled',
    'aiMealPlannerEnabled',
    'aiProductAnalysisEnabled',
    'aiMealParserEnabled',
    'aiRecalibrationEnabled',
    'aiQuickRepliesEnabled',
    'additiveInsightsEnabled',
    'alternativesEnabled',
    'maintenanceMode',
    'maintenanceMessage',
    'minAppVersion',
    'requiredTermsVersion',
    'requiredPrivacyVersion',
    'aiIpPerMinuteLimit',
    'macroMaxAdjustmentPercent',
  ];

  for (const key of scalarKeys) {
    if (draft[key] !== undefined && draft[key] !== baseline[key]) {
      patch[key] = draft[key];
    }
  }

  const baseLimits = baseline.aiDailyLimits ?? {};
  const draftLimits = draft.aiDailyLimits ?? {};
  const limitDiff: Record<string, number> = {};
  for (const k of ['chat', 'meal', 'plan', 'analysis', 'macros', 'quickReplies'] as const) {
    if (draftLimits[k] !== undefined && draftLimits[k] !== baseLimits[k]) {
      limitDiff[k] = Number(draftLimits[k]);
    }
  }
  if (Object.keys(limitDiff).length > 0) {
    patch.aiDailyLimits = { ...baseLimits, ...draftLimits };
  }
  return patch;
}

export function splitCsvTags(raw: string): string[] {
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

export function validateSemverOrEmpty(value: string): boolean {
  const v = value.trim();
  return v === '' || /^\d+\.\d+\.\d+$/.test(v);
}
