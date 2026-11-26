import { describe, expect, it } from 'vitest';
import {
  AdminApiError,
  buildFlagPatchDiff,
  callAdminAction,
  splitCsvTags,
  validateSemverOrEmpty,
} from './adminClient';

describe('adminClient helpers & RPC transport', () => {
  it('computes minimal diff patch for scalar flags and daily limits', () => {
    const baseline = {
      aiEnabled: true,
      maintenanceMode: false,
      minAppVersion: '1.0.2',
      aiDailyLimits: { chat: 40, plan: 8 },
    };
    const draft = {
      ...baseline,
      maintenanceMode: true,
      maintenanceMessage: 'Upgrade in progress',
      aiDailyLimits: { chat: 60, plan: 8 },
    };
    const diff = buildFlagPatchDiff(baseline, draft);
    expect(diff).toEqual({
      maintenanceMode: true,
      maintenanceMessage: 'Upgrade in progress',
      aiDailyLimits: { chat: 60, plan: 8 },
    });
  });

  it('validates semver strings and splits CSV allergen/trace tags', () => {
    expect(validateSemverOrEmpty('')).toBe(true);
    expect(validateSemverOrEmpty('1.0.4')).toBe(true);
    expect(validateSemverOrEmpty('v1.0')).toBe(false);
    expect(splitCsvTags(' milk , peanut , , soy ')).toEqual(['milk', 'peanut', 'soy']);
  });

  it('sends Bearer JWT and unwraps { result } or throws AdminApiError', async () => {
    let seenAuth = '';
    let seenBody = '';
    const ok = await callAdminAction<{ count: number }>(
      'overview',
      { extra: 1 },
      {
        edgeUrl: 'https://edge.test/admin',
        getToken: async () => 'jwt-123',
        fetcher: async (_url, init) => {
          seenAuth = (init?.headers as Record<string, string>).Authorization;
          seenBody = String(init?.body ?? '');
          return new Response(JSON.stringify({ result: { count: 7 } }), { status: 200 });
        },
      },
    );
    expect(seenAuth).toBe('Bearer jwt-123');
    expect(JSON.parse(seenBody)).toEqual({ action: 'overview', extra: 1 });
    expect(ok.count).toBe(7);

    await expect(
      callAdminAction(
        'overview',
        {},
        {
          edgeUrl: 'https://edge.test/admin',
          getToken: async () => 'jwt-123',
          fetcher: async () =>
            new Response(
              JSON.stringify({ error: { status: 'PERMISSION_DENIED', message: 'Admin role required' } }),
              { status: 403 },
            ),
        },
      ),
    ).rejects.toMatchObject({
      name: 'AdminApiError',
      status: 403,
      code: 'PERMISSION_DENIED',
      message: 'Admin role required',
    } satisfies Partial<AdminApiError>);
  });

  it('fails closed when no Firebase ID token is available', async () => {
    await expect(
      callAdminAction('overview', {}, { getToken: async () => null }),
    ).rejects.toMatchObject({ status: 401, code: 'UNAUTHENTICATED' });
  });
});
