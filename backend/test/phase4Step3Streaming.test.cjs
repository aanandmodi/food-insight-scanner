const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  createJsonReplyStreamExtractor,
  requestAiStream,
  resetProviderCircuitsForTest,
} = require('../lib/aiProvider');

function sseResponse(lines) {
  const encoder = new TextEncoder();
  return new Response(
    new ReadableStream({
      start(controller) {
        for (const chunk of lines) {
          controller.enqueue(encoder.encode(chunk));
        }
        controller.close();
      },
    }),
    { status: 200, headers: { 'content-type': 'text/event-stream' } },
  );
}

test('createJsonReplyStreamExtractor decodes reply tokens progressively across key orders and escapes', () => {
  const extractor = createJsonReplyStreamExtractor();
  const chunks = [
    '{"mealData":null,"re',
    'ply":"Try **2 rotis**\\n',
    'with \\"dal\\" \\u0026 curd',
    '!","ignored":"x"}',
  ];
  const streamed = chunks.map((c) => extractor.feed(c)).join('');
  assert.equal(streamed, 'Try **2 rotis**\nwith "dal" & curd!');
  assert.equal(JSON.parse(extractor.rawText()).reply, 'Try **2 rotis**\nwith "dal" & curd!');
});

test('requestAiStream streams Groq SSE tokens cleanly and fails over to Gemini SSE on 429', async () => {
  resetProviderCircuitsForTest();
  const deltas = [];
  const res = await requestAiStream(
    'chat',
    'groq-key',
    [{ role: 'user', content: 'Dinner ideas?' }],
    (t) => deltas.push(t),
    async (url) => {
      if (String(url).includes('api.groq.com')) {
        return new Response('', { status: 429, headers: { 'retry-after': '30' } });
      }
      assert.ok(String(url).includes('streamGenerateContent?alt=sse'));
      return sseResponse([
        'data: {"candidates":[{"content":{"parts":[{"text":"{\\"reply\\":\\"Try "}]}}]}\n\n',
        'data: {"candidates":[{"content":{"parts":[{"text":"khichdi with curd.\\",\\"mealData\\":null}"}]},"finishReason":"STOP"}]}\n\n',
      ]);
    },
    {},
    { geminiApiKey: 'gemini-key' },
  );

  assert.equal(deltas.join(''), 'Try khichdi with curd.');
  assert.equal(res.reply, 'Try khichdi with curd.');
  assert.equal(res.mealData, null);
  resetProviderCircuitsForTest();
});
