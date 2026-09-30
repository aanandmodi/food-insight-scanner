// Deprecated endpoint. Deploy this response before disabling the old ai-proxy
// function so older clients receive a controlled response without Groq access.
Deno.serve(() => Response.json(
  { error: 'This AI endpoint has been retired. Update Food Insight to continue.' },
  { status: 410, headers: { 'Content-Type': 'application/json' } },
));
