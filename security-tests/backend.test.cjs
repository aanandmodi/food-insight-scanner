const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8088';
process.env.GCLOUD_PROJECT = 'demo-food-insight';
process.env.GROQ_API_KEY = 'test-fixture-not-a-key';
const backendRequire = require('node:module').createRequire(require('node:path').resolve('../backend/package.json'));
const { initializeApp, deleteApp } = backendRequire('firebase-admin/app');
const { getFirestore } = backendRequire('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-food-insight' });
const db = getFirestore(app);
const { aiTask } = require('../backend/lib/aiTask');
const { scanProduct } = require('../backend/lib/scanProduct');
const realFetch = global.fetch;
const request = (uid, data) => ({ auth: { uid, token: { firebase: { sign_in_provider: 'password' } } }, data });
const meal = { name: 'Rice', calories: 200, protein: 4, carbs: 40, sugar: 0, fat: 2 };
before(async () => { await db.doc('config/featureFlags').set({ aiEnabled: true }); });
after(async () => { global.fetch = realFetch; await deleteApp(app); });
test('kill switch rejects AI before any provider request', async () => {
  await db.doc('config/featureFlags').set({ aiEnabled: false });
  let called = false;
  global.fetch = async () => { called = true; throw new Error('Unexpected provider call'); };
  await assert.rejects(aiTask.run(request('backend-disabled', { task: 'meal', content: 'rice' })), { code: 'failed-precondition' });
  assert.equal(called, false);
  await db.doc('config/featureFlags').set({ aiEnabled: true, aiDailyLimits: { meal: 1 } });
});
test('concurrent AI attempts cannot overspend a UID quota', async () => {
  let calls = 0;
  global.fetch = async () => { calls++; return new Response(JSON.stringify({ choices: [{ finish_reason: 'stop', message: { content: JSON.stringify(meal) } }] })); };
  const results = await Promise.allSettled([1,2].map(() => aiTask.run(request('backend-race', { task: 'meal', content: 'rice' }))));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(calls, 1);
  assert.equal((await db.doc('users/backend-race/aiUsage/current').get()).data().meal, 1);
});
test('malformed provider response is rejected and still consumes the attempt', async () => {
  global.fetch = async () => new Response(JSON.stringify({ choices: [{ finish_reason: 'stop', message: { content: '{broken' } }] }));
  await assert.rejects(aiTask.run(request('backend-malformed', { task: 'meal', content: 'rice' })), { code: 'unavailable' });
  assert.equal((await db.doc('users/backend-malformed/aiUsage/current').get()).data().meal, 1);
});
test('product API persists canonical units and cache avoids a second OFF call', async () => {
  let calls = 0;
  global.fetch = async () => { calls++; return new Response(JSON.stringify({ status: 1, product: { product_name: 'Fixture', nutriments: { sodium_100g: 0.75 } } })); };
  const input = request('backend-scanner', { barcode: '99887766' });
  assert.equal((await scanProduct.run(input)).nutrition.sodiumMgPer100g, 750);
  assert.equal((await scanProduct.run(input)).nutrition.sodiumMgPer100g, 750);
  assert.equal(calls, 1);
});
test('account deletion guard blocks backend access even with a stale verified token', async () => {
  await db.doc('accountDeletionGuards/backend-deleted').set({ deleting: true });
  await assert.rejects(scanProduct.run(request('backend-deleted', { barcode: '99887766' })), { code: 'permission-denied' });
  await assert.rejects(aiTask.run(request('backend-deleted', { task: 'meal', content: 'rice' })), { code: 'permission-denied' });
});
