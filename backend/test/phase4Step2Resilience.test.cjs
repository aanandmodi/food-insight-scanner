const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  requestAi,
  geminiModelFor,
  resetProviderCircuitsForTest,
  isProviderCircuitOpen,
} = require('../lib/aiProvider');
const { consumeAiQuota, hashClientIp, GUEST_DAILY_LIMITS } = require('../lib/quotaService');
const { limits } = require('../lib/aiValidation');

test('Groq 429 seamlessly fails over to Gemini Flash with x-goog-api-key header', async () => {
  resetProviderCircuitsForTest();
  const requests = [];
  const result = await requestAi(
    'chat',
    'groq-secret-token',
    [
      { role: 'system', content: 'Be helpful JSON.' },
      { role: 'user', content: 'How much protein in 200g curd?' },
    ],
    async (url, init) => {
      requests.push({ url: String(url), headers: init.headers, body: JSON.parse(init.body) });
      if (String(url).includes('api.groq.com')) {
        return new Response('', { status: 429, headers: { 'retry-after': '45' } });
      }
      return new Response(
        JSON.stringify({
          candidates: [
            {
              finishReason: 'STOP',
              content: { parts: [{ text: '{"reply":"About 7g protein.","mealData":null}' }] },
            },
          ],
        }),
        { status: 200 },
      );
    },
    {},
    { geminiApiKey: 'gemini-secret-token' },
  );

  assert.equal(result.reply, 'About 7g protein.');
  assert.equal(requests.length, 2);
  assert.ok(requests[0].url.includes('api.groq.com'));
  assert.ok(requests[1].url.includes('generativelanguage.googleapis.com'));
  assert.ok(!requests[1].url.includes('gemini-secret-token'));
  assert.equal(requests[1].headers['x-goog-api-key'], 'gemini-secret-token');
  assert.equal(isProviderCircuitOpen('groq'), true);

  // Subsequent call skips throttled Groq directly and succeeds on Gemini.
  const callsWhenCircuitOpen = [];
  await requestAi(
    'meal',
    'groq-secret-token',
    [{ role: 'user', content: '1 roti' }],
    async (url) => {
      callsWhenCircuitOpen.push(String(url));
      return new Response(
        JSON.stringify({
          candidates: [
            { finishReason: 'STOP', content: { parts: [{ text: '{"name":"Roti","calories":104,"protein":3,"carbs":20,"fat":1.5,"sugar":0.5}' }] } },
          ],
        }),
        { status: 200 },
      );
    },
    {},
    { geminiApiKey: 'gemini-secret-token' },
  );
  assert.equal(callsWhenCircuitOpen.length, 1);
  assert.ok(callsWhenCircuitOpen[0].includes('generativelanguage.googleapis.com'));
  resetProviderCircuitsForTest();
});

test('Gemini Flash fallback also recovers from Groq 5xx errors and masks credentials when both fail', async () => {
  resetProviderCircuitsForTest();
  assert.equal(geminiModelFor('plan', {}), 'gemini-2.5-flash');

  await assert.rejects(
    requestAi(
      'chat',
      'groq-super-secret',
      [{ role: 'user', content: 'hi' }],
      async (url) => {
        if (String(url).includes('api.groq.com')) {
          return new Response('', { status: 503 });
        }
        return new Response('', { status: 429, headers: { 'retry-after': '90' } });
      },
      { AI_MODEL_FAST: 'fast-groq', AI_MODEL_SMART: 'smart-groq', AI_MODEL_FALLBACK: 'backup-groq' },
      { geminiApiKey: 'gemini-super-secret', bypassCircuit: true },
    ),
    (err) => {
      assert.equal(err.code, 'resource-exhausted');
      assert.equal(err.details.retryAfterSeconds, 90);
      assert.ok(!err.message.includes('groq-super-secret'));
      assert.ok(!err.message.includes('gemini-super-secret'));
      return true;
    },
  );
  resetProviderCircuitsForTest();
});

test('hashClientIp produces stable non-reversible digest and PostgreSQL quota RPC handles tiers & floods', async () => {
  const hashA = await hashClientIp('203.0.113.42, 10.0.0.1', 'unit-salt');
  const hashB = await hashClientIp('203.0.113.42', 'unit-salt');
  assert.ok(hashA && hashA.length === 64);
  assert.equal(hashA, hashB);
  assert.ok(!hashA.includes('203.0.113.42'));

  assert.equal(GUEST_DAILY_LIMITS.chat, 3);
  assert.equal(GUEST_DAILY_LIMITS.meal, 3);
  assert.equal(GUEST_DAILY_LIMITS.plan, 1);
  assert.equal(limits.chat, 20);
  assert.equal(limits.meal, 15);
  assert.equal(limits.analysis, 15);
  assert.equal(limits.plan, 2);

  let sentRpcBody;
  const ok = await consumeAiQuota({
    uid: 'guest-uid',
    task: 'chat',
    isGuest: true,
    ipHash: hashA,
    supabaseUrl: 'https://example.supabase.co',
    serviceRoleKey: 'srv-secret',
    fetcher: async (url, init) => {
      assert.equal(String(url), 'https://example.supabase.co/rest/v1/rpc/check_and_consume_ai_quota');
      sentRpcBody = JSON.parse(init.body);
      return new Response(JSON.stringify({ allowed: true, used: 1, limit: 3, remaining: 2 }), { status: 200 });
    },
  });
  assert.equal(ok.backend, 'postgres');
  assert.equal(ok.limit, 3);
  assert.equal(sentRpcBody.p_is_guest, true);
  assert.equal(sentRpcBody.p_ip_per_minute_limit, 30);

  await assert.rejects(
    consumeAiQuota({
      uid: 'user-1',
      task: 'chat',
      isGuest: false,
      ipHash: hashA,
      supabaseUrl: 'https://example.supabase.co',
      serviceRoleKey: 'srv-secret',
      fetcher: async () => new Response(JSON.stringify({ allowed: false, reason: 'ip-flood', retryAfterSeconds: 42 }), { status: 200 }),
    }),
    (err) => err.code === 'resource-exhausted' && err.details.reason === 'ip-flood' && err.details.retryAfterSeconds === 42,
  );
});
