const { test } = require('node:test');
const assert = require('node:assert/strict');
const { modelsFor, requestAi } = require('../lib/aiProvider');
const ok = () => new Response(JSON.stringify({choices:[{finish_reason:'stop',message:{content:'{"reply":"Hello"}'}}]}));
const env = { AI_MODEL_FAST:'fast', AI_MODEL_SMART:'smart', AI_MODEL_FALLBACK:'backup' };

test('model routing is server-configurable and deduplicates fallback', () => {
  assert.deepEqual(modelsFor('meal', env), ['fast','backup']);
  assert.deepEqual(modelsFor('analysis', env), ['fast','backup']);
  for (const task of ['chat','plan','macros']) assert.deepEqual(modelsFor(task, env), ['smart','backup']);
  assert.deepEqual(modelsFor('meal', {}), ['openai/gpt-oss-20b']);
});
test('transient error falls back exactly once', async () => {
  const called = [];
  const result = await requestAi('chat','private',[], async (_, init) => {
    called.push(JSON.parse(init.body).model);
    return called.length === 1 ? new Response('',{status:503}) : ok();
  }, env);
  assert.deepEqual(called,['smart','backup']);
  assert.equal(result.reply,'Hello');
});
test('429 returns bounded retry hint without fallback', async () => {
  let calls = 0;
  await assert.rejects(requestAi('chat','private',[],async () => {
    calls++; return new Response('',{status:429,headers:{'retry-after':'120'}});
  },env), e => e.code === 'resource-exhausted' && e.details.retryAfterSeconds === 120);
  assert.equal(calls,1);
});
test('timeouts stop after two attempts and never expose credentials', async () => {
  let calls=0;
  await assert.rejects(requestAi('chat','private',[],async () => {calls++;throw Error('private');},env),
    e => e.code === 'unavailable' && !e.message.includes('private'));
  assert.equal(calls,2);
});
test('invalid output and authentication errors are not retried', async () => {
  for (const response of [new Response('bad'),new Response('',{status:401})]) {
    let calls=0;
    await assert.rejects(requestAi('chat','private',[],async () => {calls++;return response;},env));
    assert.equal(calls,1);
  }
});
