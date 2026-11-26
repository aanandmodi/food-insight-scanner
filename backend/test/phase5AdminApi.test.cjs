const { test } = require('node:test');
const assert = require('node:assert/strict');

const { runAdminAction } = require('../lib/adminApi');
const { assertAccountActive } = require('../lib/accountStatus');

const adminAuth = {
  uid: 'admin-1',
  token: {
    email: 'ops@example.com',
    email_verified: true,
    role: 'admin',
    firebase: { sign_in_provider: 'password' },
  },
};

function makeFakeDeps(overrides = {}) {
  const restCalls = [];
  const auditLogs = [];
  const state = {
    flags: { aiEnabled: true, maintenanceMode: false, maintenanceMessage: '', minAppVersion: '1.0.2' },
    products: new Map(),
    suspensions: new Map(),
    deletionGuards: new Set(),
    purgedUsers: [],
    deletedAuthUsers: [],
    disabledUpdates: [],
  };

  const deps = {
    supabaseUrl: 'https://example.supabase.co',
    supabaseServiceKey: 'test-service-key',
    readFlags: async () => ({ ...state.flags }),
    writeFlags: async (patch) => {
      Object.assign(state.flags, patch);
    },
    readProduct: async (barcode) => state.products.get(barcode) ?? null,
    writeProduct: async (barcode, product) => {
      state.products.set(barcode, product);
    },
    setSuspensionDoc: async (uid, active, reason, by) => {
      if (active) state.suspensions.set(uid, { active: true, reason, updatedBy: by });
      else state.suspensions.delete(uid);
    },
    readSuspensionDoc: async (uid) => state.suspensions.get(uid) ?? null,
    readDeletionGuard: async (uid) => state.deletionGuards.has(uid),
    lookupAuthUser: async ({ uid, email }) => ({
      uid: uid || 'user-42',
      email: email || 'user42@example.com',
      emailVerified: true,
      disabled: state.suspensions.has(uid || 'user-42'),
      displayName: 'Test User',
      providers: ['password'],
      customClaims: {},
    }),
    updateAuthDisabled: async (uid, disabled) => {
      state.disabledUpdates.push({ uid, disabled });
    },
    purgeUser: async (uid) => {
      state.purgedUsers.push(uid);
    },
    deleteAuthUser: async (uid) => {
      state.deletedAuthUsers.push(uid);
    },
    fetcher: async (url, init = {}) => {
      const target = String(url);
      const method = init.method || 'GET';
      const body = init.body ? JSON.parse(init.body) : undefined;
      restCalls.push({ target, method, body });

      if (target.includes('/rest/v1/admin_audit_logs') && method === 'POST') {
        auditLogs.push(body);
        return new Response('', { status: 201 });
      }
      if (target.includes('/rest/v1/ai_provider_health')) {
        return new Response(JSON.stringify([{ provider: 'groq', consecutive_failures: 0 }]), { status: 200 });
      }
      if (target.includes('/rest/v1/ai_user_quotas')) {
        return new Response(JSON.stringify([{ user_id: 'user-42', task: 'chat', daily_count: 5 }]), { status: 200 });
      }
      if (target.includes('/rest/v1/ai_ip_rate_limits')) {
        return new Response(JSON.stringify([]), { status: 200 });
      }
      if (target.includes('/rest/v1/ai_abuse_events')) {
        return new Response(JSON.stringify([{ id: 'ab-1', severity: 'high', category: 'role_hijack' }]), { status: 200 });
      }
      if (target.includes('/rest/v1/product_reports') && method === 'POST') {
        return new Response(JSON.stringify([{ id: 'rep-1', status: 'open' }]), { status: 201 });
      }
      if (target.includes('/rest/v1/product_reports')) {
        return new Response(JSON.stringify([{ id: 'rep-1', barcode: '8901234567890', status: 'open' }]), { status: 200 });
      }
      if (target.includes('/rest/v1/deletion_requests') && method === 'POST') {
        return new Response(JSON.stringify([{ id: 'del-1', ...body }]), { status: 201 });
      }
      if (target.includes('/rest/v1/deletion_requests')) {
        return new Response(JSON.stringify([{ id: 'del-1', status: 'pending' }]), { status: 200 });
      }
      if (target.includes('/rest/v1/food_additives_overrides') && method === 'POST') {
        return new Response(JSON.stringify([body]), { status: 201 });
      }
      if (target.includes('/rest/v1/food_additives_overrides')) {
        return new Response(JSON.stringify([{ ins: '102', name: 'Tartrazine', safety_tier: 'caution' }]), { status: 200 });
      }
      return new Response(JSON.stringify([]), { status: 200 });
    },
    ...overrides,
  };

  return { deps, state, restCalls, auditLogs };
}

test('assertAccountActive enforces deletion guard and active user suspension', async () => {
  const makeDb = (docs) => ({
    doc: (path) => ({
      get: async () => ({
        exists: Object.prototype.hasOwnProperty.call(docs, path),
        data: () => docs[path],
      }),
    }),
  });

  await assertAccountActive(makeDb({}), 'u1');
  await assertAccountActive(makeDb({ 'userSuspensions/u1': { active: false } }), 'u1');

  await assert.rejects(
    () => assertAccountActive(makeDb({ 'accountDeletionGuards/u1': { startedAt: '2026-11-26' } }), 'u1'),
    (err) => err.code === 'permission-denied' && /deletion/i.test(err.message),
  );

  await assert.rejects(
    () => assertAccountActive(makeDb({ 'userSuspensions/u1': { active: true } }), 'u1'),
    (err) => err.code === 'permission-denied' && /suspended/i.test(err.message),
  );
});

test('runAdminAction rejects unauthenticated, anonymous, unverified, and non-admin callers', async () => {
  const { deps } = makeFakeDeps();

  await assert.rejects(
    () => runAdminAction({ data: { action: 'overview' } }, deps),
    (err) => err.code === 'unauthenticated',
  );

  await assert.rejects(
    () => runAdminAction({ auth: { uid: 'anon-1', token: { firebase: { sign_in_provider: 'anonymous' } } }, data: { action: 'overview' } }, deps),
    (err) => err.code === 'permission-denied',
  );

  await assert.rejects(
    () => runAdminAction({ auth: { uid: 'u1', token: { email_verified: false, role: 'admin' } }, data: { action: 'overview' } }, deps),
    (err) => err.code === 'permission-denied',
  );

  await assert.rejects(
    () => runAdminAction({ auth: { uid: 'u1', token: { email_verified: true, firebase: { sign_in_provider: 'password' } } }, data: { action: 'overview' } }, deps),
    (err) => err.code === 'permission-denied',
  );
});

test('runAdminAction overview and updateConfig validate allowlist and log immutable audits', async () => {
  const { deps, state, auditLogs } = makeFakeDeps();

  const overview = await runAdminAction({ auth: adminAuth, data: { action: 'overview' } }, deps);
  assert.equal(overview.metrics.aiRequestsToday, 5);
  assert.equal(overview.metrics.openReportsCount, 1);

  const updated = await runAdminAction({
    auth: { uid: 'admin-2', token: { email: 'lead@example.com', email_verified: true, admin: true } },
    data: {
      action: 'updateConfig',
      patch: {
        maintenanceMode: true,
        maintenanceMessage: 'Scheduled upgrade',
        minAppVersion: '1.0.5',
        requiredTermsVersion: '2026-11-26',
        aiIpPerMinuteLimit: 40,
        macroMaxAdjustmentPercent: 8,
        aiDailyLimits: { chat: 50, plan: 10 },
        disallowedSecretField: 'ignored',
      },
    },
  }, deps);

  assert.equal(updated.flags.maintenanceMode, true);
  assert.equal(updated.flags.minAppVersion, '1.0.5');
  assert.equal('disallowedSecretField' in state.flags, false);
  assert.equal(auditLogs.at(-1).action, 'update_config');

  await assert.rejects(
    () => runAdminAction({ auth: adminAuth, data: { action: 'updateConfig', patch: { minAppVersion: 'v1' } } }, deps),
    (err) => err.code === 'invalid-argument',
  );
  await assert.rejects(
    () => runAdminAction({ auth: adminAuth, data: { action: 'updateConfig', patch: { macroMaxAdjustmentPercent: 25 } } }, deps),
    (err) => err.code === 'invalid-argument',
  );
  await assert.rejects(
    () => runAdminAction({ auth: adminAuth, data: { action: 'updateConfig', patch: { unknownKey: true } } }, deps),
    (err) => err.code === 'invalid-argument',
  );
});

test('runAdminAction manages circuits, quotas, user suspension, deletion, catalog, and additives', async () => {
  const { deps, state, restCalls, auditLogs } = makeFakeDeps();

  await runAdminAction({ auth: adminAuth, data: { action: 'resetProviderCircuit', provider: 'groq' } }, deps);
  await runAdminAction({ auth: adminAuth, data: { action: 'resetUserQuota', userId: 'user-42', task: 'chat' } }, deps);
  const abuse = await runAdminAction({ auth: adminAuth, data: { action: 'listAbuseEvents', severity: 'high' } }, deps);
  assert.equal(abuse.events.length, 1);

  await assert.rejects(
    () => runAdminAction({ auth: adminAuth, data: { action: 'toggleUserSuspension', userId: 'admin-1', suspend: true } }, deps),
    (err) => err.code === 'failed-precondition',
  );

  await runAdminAction({ auth: adminAuth, data: { action: 'toggleUserSuspension', userId: 'user-42', suspend: true, reason: 'Abuse' } }, deps);
  assert.equal(state.disabledUpdates[0].disabled, true);
  const lookedUp = await runAdminAction({ auth: adminAuth, data: { action: 'lookupUser', uid: 'user-42' } }, deps);
  assert.equal(lookedUp.suspended, true);

  await assert.rejects(
    () => runAdminAction({ auth: adminAuth, data: { action: 'deleteUserAccount', userId: 'user-42', confirmUid: 'wrong' } }, deps),
    (err) => err.code === 'invalid-argument',
  );

  const deleted = await runAdminAction({
    auth: adminAuth,
    data: { action: 'deleteUserAccount', userId: 'user-42', confirmUid: 'user-42', deletionRequestId: 'del-1' },
  }, deps);
  assert.equal(deleted.deleted, true);
  assert.deepEqual(state.purgedUsers, ['user-42']);
  assert.deepEqual(state.deletedAuthUsers, ['user-42']);

  const savedProduct = await runAdminAction({
    auth: adminAuth,
    data: {
      action: 'saveCanonicalProduct',
      barcode: '8901234567890',
      resolveReportId: 'rep-1',
      product: {
        name: 'Whole Wheat Atta',
        brand: 'FreshMill',
        nutrition: { calories: 340, protein: 12, carbs: 70, fat: 2 },
        allergens: ['Gluten'],
      },
    },
  }, deps);
  assert.equal(savedProduct.product.adminVerified, true);
  assert.equal(savedProduct.product.nutrition.energyKcalPer100g, 340);
  assert.ok(restCalls.some((c) => c.target.includes('/product_reports?id=eq.rep-1') && c.method === 'PATCH'));

  const upsertedAdd = await runAdminAction({
    auth: adminAuth,
    data: {
      action: 'upsertAdditiveOverride',
      ins: '102',
      name: 'Tartrazine',
      safetyTier: 'caution',
      summary: 'Synthetic food dye',
    },
  }, deps);
  assert.equal(upsertedAdd.additive.ins, '102');

  await runAdminAction({ auth: adminAuth, data: { action: 'deleteAdditiveOverride', ins: '102' } }, deps);
  assert.ok(auditLogs.some((l) => l.action === 'delete_additive_override'));

  const { adminAction } = require('../lib/adminExports');
  assert.equal(typeof adminAction.run, 'function');
});
