import { assertEquals, assertMatch } from "jsr:@std/assert@1";

import { createAdminEdgeHandler } from "./handler.ts";

Deno.test("CORS rejects untrusted origin without ACAO header and allows localhost preflight", async () => {
  const handler = createAdminEdgeHandler({
    verifyAdminToken: async () => ({ uid: "u1", token: { email_verified: true, role: "admin" } }),
    runAdminAction: async () => ({ ok: true }),
  });

  const evilPreflight = await handler(
    new Request("https://edge.test/admin", {
      method: "OPTIONS",
      headers: { Origin: "https://evil.example" },
    }),
  );
  assertEquals(evilPreflight.status, 403);
  assertEquals(evilPreflight.headers.get("access-control-allow-origin"), null);

  const okPreflight = await handler(
    new Request("https://edge.test/admin", {
      method: "OPTIONS",
      headers: { Origin: "http://localhost:5173" },
    }),
  );
  assertEquals(okPreflight.status, 204);
  assertEquals(okPreflight.headers.get("access-control-allow-origin"), "http://localhost:5173");
});

Deno.test("Admin edge enforces Bearer JWT, body size limit, and HttpsError status mapping", async () => {
  let verifiedToken = "";
  const handler = createAdminEdgeHandler({
    verifyAdminToken: async (token) => {
      verifiedToken = token;
      if (token === "bad-token") throw new Error("revoked");
      return { uid: "admin-1", token: { email: "ops@example.com", email_verified: true, role: "admin" } };
    },
    runAdminAction: async ({ data }) => {
      if (data.action === "forbidden") {
        throw Object.assign(new Error("Admin role claim required."), { code: "permission-denied" });
      }
      return { action: data.action, ok: true };
    },
  });

  const noAuth = await handler(new Request("https://edge.test/admin", { method: "POST", body: "{}" }));
  assertEquals(noAuth.status, 401);

  const revoked = await handler(
    new Request("https://edge.test/admin", {
      method: "POST",
      headers: { Authorization: "Bearer bad-token" },
      body: "{}",
    }),
  );
  assertEquals(revoked.status, 401);

  const oversized = await handler(
    new Request("https://edge.test/admin", {
      method: "POST",
      headers: { Authorization: "Bearer good-token" },
      body: JSON.stringify({ data: "x".repeat(70000) }),
    }),
  );
  assertEquals(oversized.status, 413);

  const denied = await handler(
    new Request("https://edge.test/admin", {
      method: "POST",
      headers: { Authorization: "Bearer good-token", Origin: "http://localhost:5173" },
      body: JSON.stringify({ action: "forbidden" }),
    }),
  );
  assertEquals(denied.status, 403);

  const ok = await handler(
    new Request("https://edge.test/admin", {
      method: "POST",
      headers: { Authorization: "Bearer good-token", Origin: "http://localhost:5173" },
      body: JSON.stringify({ data: { action: "overview" } }),
    }),
  );
  assertEquals(verifiedToken, "good-token");
  assertEquals(ok.status, 200);
  const body = await ok.json();
  assertEquals(body.result.action, "overview");
  assertMatch(ok.headers.get("cache-control") ?? "", /no-store/);
});
