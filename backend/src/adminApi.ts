import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { cleanupUserData } from "./accountDeletion";
import { AiTask } from "./aiValidation";
import { resetProviderCircuitsForTest } from "./aiProvider";
import { readSecretOrEnv, supabaseAdminKey } from "./secrets";

if (!getApps().length) initializeApp();

const SUPABASE_DEFAULT_URL = "https://tslcgavpkujkfexzmisk.supabase.co";
const BARCODE_PATTERN = /^\d{8,14}$/;
const TASK_KEYS: AiTask[] = ["chat", "meal", "plan", "analysis", "macros", "quickReplies"];

const BOOLEAN_FLAGS = [
  "aiEnabled",
  "aiChatEnabled",
  "mealPlannerEnabled",
  "aiMealPlannerEnabled",
  "aiProductAnalysisEnabled",
  "aiMealParserEnabled",
  "aiRecalibrationEnabled",
  "aiQuickRepliesEnabled",
  "additiveInsightsEnabled",
  "alternativesEnabled",
  "maintenanceMode",
] as const;

export interface AdminAuthContext {
  uid: string;
  token?: Record<string, unknown> & {
    email?: unknown;
    email_verified?: unknown;
    role?: unknown;
    admin?: unknown;
    firebase?: { sign_in_provider?: unknown };
  };
}

export interface AdminActionRequest {
  auth?: AdminAuthContext;
  data?: unknown;
}

export interface AdminDeps {
  supabaseUrl?: string;
  supabaseServiceKey?: string;
  fetcher?: typeof fetch;
  readFlags?: () => Promise<Record<string, any>>;
  writeFlags?: (patch: Record<string, any>) => Promise<void>;
  readProduct?: (barcode: string) => Promise<Record<string, any> | null>;
  writeProduct?: (barcode: string, product: Record<string, any>) => Promise<void>;
  setSuspensionDoc?: (uid: string, active: boolean, reason: string, adminUid: string) => Promise<void>;
  readSuspensionDoc?: (uid: string) => Promise<Record<string, any> | null>;
  readDeletionGuard?: (uid: string) => Promise<boolean>;
  lookupAuthUser?: (opts: { uid?: string; email?: string }) => Promise<Record<string, any> | null>;
  updateAuthDisabled?: (uid: string, disabled: boolean) => Promise<void>;
  purgeUser?: (uid: string) => Promise<void>;
  deleteAuthUser?: (uid: string) => Promise<void>;
}

function defaultDeps(overrides: AdminDeps = {}): Required<AdminDeps> {
  const db = getFirestore();
  const auth = getAuth();
  const key =
    overrides.supabaseServiceKey ??
    readSecretOrEnv(supabaseAdminKey, "SUPABASE_SERVICE_ROLE_KEY") ??
    "";

  return {
    supabaseUrl: (overrides.supabaseUrl || process.env.SUPABASE_URL || SUPABASE_DEFAULT_URL).replace(/\/+$/, ""),
    supabaseServiceKey: key,
    fetcher: overrides.fetcher ?? fetch,
    readFlags: overrides.readFlags ?? (async () => (await db.doc("config/featureFlags").get()).data() ?? {}),
    writeFlags: overrides.writeFlags ?? (async (patch) => { await db.doc("config/featureFlags").set(patch, { merge: true }); }),
    readProduct: overrides.readProduct ?? (async (barcode) => (await db.doc(`products/${barcode}`).get()).data() ?? null),
    writeProduct: overrides.writeProduct ?? (async (barcode, product) => { await db.doc(`products/${barcode}`).set(product, { merge: true }); }),
    setSuspensionDoc: overrides.setSuspensionDoc ?? (async (uid, active, reason, adminUid) => {
      const ref = db.doc(`userSuspensions/${uid}`);
      if (active) {
        await ref.set({ active: true, reason, updatedBy: adminUid, updatedAt: new Date().toISOString() });
      } else {
        await ref.delete();
      }
    }),
    readSuspensionDoc: overrides.readSuspensionDoc ?? (async (uid) => (await db.doc(`userSuspensions/${uid}`).get()).data() ?? null),
    readDeletionGuard: overrides.readDeletionGuard ?? (async (uid) => (await db.doc(`accountDeletionGuards/${uid}`).get()).exists),
    lookupAuthUser: overrides.lookupAuthUser ?? (async ({ uid, email }) => {
      try {
        const u = uid ? await auth.getUser(uid) : email ? await auth.getUserByEmail(email) : null;
        if (!u) return null;
        return {
          uid: u.uid,
          email: u.email ?? null,
          emailVerified: u.emailVerified,
          disabled: u.disabled,
          displayName: u.displayName ?? null,
          providers: u.providerData.map((p) => p.providerId),
          createdAt: u.metadata.creationTime ?? null,
          lastSignInAt: u.metadata.lastSignInTime ?? null,
          customClaims: u.customClaims ?? {},
        };
      } catch {
        return null;
      }
    }),
    updateAuthDisabled: overrides.updateAuthDisabled ?? (async (uid, disabled) => {
      await auth.updateUser(uid, { disabled });
      if (disabled) await auth.revokeRefreshTokens(uid);
    }),
    purgeUser: overrides.purgeUser ?? cleanupUserData,
    deleteAuthUser: overrides.deleteAuthUser ?? (async (uid) => { await auth.deleteUser(uid); }),
  };
}

function cleanText(value: unknown, max: number): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function assertAdmin(auth?: AdminAuthContext): { uid: string; email: string } {
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "Sign in to access the admin portal.");
  }
  const provider = auth.token?.firebase?.sign_in_provider;
  if (provider === "anonymous" || auth.token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "Verified admin credentials required.");
  }
  const hasClaim = auth.token?.role === "admin" || auth.token?.admin === true;
  if (!hasClaim) {
    throw new HttpsError("permission-denied", "Admin role claim required.");
  }
  return {
    uid: auth.uid,
    email: cleanText(auth.token?.email, 320),
  };
}

async function sbRest(
  deps: Required<AdminDeps>,
  path: string,
  options: { method?: string; body?: unknown; prefer?: string } = {},
): Promise<any> {
  if (!deps.supabaseServiceKey) {
    throw new HttpsError("failed-precondition", "Supabase service credentials not configured.");
  }
  const response = await deps.fetcher(`${deps.supabaseUrl}/rest/v1/${path}`, {
    method: options.method ?? "GET",
    headers: {
      apikey: deps.supabaseServiceKey,
      Authorization: `Bearer ${deps.supabaseServiceKey}`,
      "Content-Type": "application/json",
      ...(options.prefer ? { Prefer: options.prefer } : {}),
    },
    ...(options.body !== undefined ? { body: JSON.stringify(options.body) } : {}),
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) {
    throw new HttpsError("unavailable", `Database request failed (${response.status}).`);
  }
  const raw = await response.text();
  return raw ? JSON.parse(raw) : null;
}

async function writeAuditLog(
  deps: Required<AdminDeps>,
  admin: { uid: string; email: string },
  action: string,
  targetType: string,
  targetId: string,
  details: Record<string, unknown>,
): Promise<void> {
  if (!deps.supabaseServiceKey) return;
  try {
    await sbRest(deps, "admin_audit_logs", {
      method: "POST",
      prefer: "return=minimal",
      body: {
        admin_uid: admin.uid.slice(0, 128),
        admin_email: admin.email.slice(0, 320),
        action: action.slice(0, 64),
        target_type: targetType.slice(0, 64),
        target_id: targetId.slice(0, 160),
        details,
      },
    });
  } catch {
    // Audit helper best-effort if DB table isn't migrated yet during partial rollout.
  }
}

function sanitizeFlagPatch(input: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {};
  for (const key of BOOLEAN_FLAGS) {
    if (key in input && typeof input[key] === "boolean") {
      patch[key] = input[key];
    }
  }
  if (typeof input.maintenanceMessage === "string") {
    patch.maintenanceMessage = input.maintenanceMessage.trim().slice(0, 300);
  }
  if (typeof input.minAppVersion === "string") {
    const v = input.minAppVersion.trim();
    if (!v || /^\d+\.\d+\.\d+$/.test(v)) {
      patch.minAppVersion = v;
    } else {
      throw new HttpsError("invalid-argument", "minAppVersion must use x.y.z format or be empty.");
    }
  }
  for (const key of ["requiredTermsVersion", "requiredPrivacyVersion"] as const) {
    if (typeof input[key] === "string") {
      const val = input[key].trim();
      if (!/^\d{4}-\d{2}-\d{2}(?:[._-][a-z0-9]+)?$/i.test(val)) {
        throw new HttpsError("invalid-argument", `${key} must be YYYY-MM-DD (optionally suffixed).`);
      }
      patch[key] = val;
    }
  }
  if (input.aiIpPerMinuteLimit !== undefined) {
    const n = Number(input.aiIpPerMinuteLimit);
    if (!Number.isInteger(n) || n < 1 || n > 500) {
      throw new HttpsError("invalid-argument", "aiIpPerMinuteLimit must be between 1 and 500.");
    }
    patch.aiIpPerMinuteLimit = n;
  }
  if (input.macroMaxAdjustmentPercent !== undefined) {
    const n = Number(input.macroMaxAdjustmentPercent);
    if (!Number.isFinite(n) || n < 0 || n > 10) {
      throw new HttpsError("invalid-argument", "macroMaxAdjustmentPercent must be between 0 and 10.");
    }
    patch.macroMaxAdjustmentPercent = n;
  }
  if (input.aiDailyLimits && typeof input.aiDailyLimits === "object" && !Array.isArray(input.aiDailyLimits)) {
    const cleanLimits: Record<string, number> = {};
    for (const task of TASK_KEYS) {
      const raw = (input.aiDailyLimits as Record<string, unknown>)[task];
      if (raw !== undefined) {
        const n = Number(raw);
        if (!Number.isInteger(n) || n < 0 || n > 500) {
          throw new HttpsError("invalid-argument", `Daily limit for ${task} must be 0–500.`);
        }
        cleanLimits[task] = n;
      }
    }
    if (Object.keys(cleanLimits).length > 0) {
      patch.aiDailyLimits = cleanLimits;
    }
  }
  if (Object.keys(patch).length === 0) {
    throw new HttpsError("invalid-argument", "No valid configuration fields provided.");
  }
  return patch;
}

function sanitizeCanonicalProductPatch(
  barcode: string,
  payload: Record<string, unknown>,
  admin: { uid: string; email: string },
): Record<string, any> {
  const name = cleanText(payload.name, 160);
  if (!name) throw new HttpsError("invalid-argument", "Product name is required.");
  const brand = cleanText(payload.brand, 120);
  const category = cleanText(payload.category, 200);
  const ingredientsText = cleanText(payload.ingredientsText, 20000);
  const nut = (payload.nutrition && typeof payload.nutrition === "object" ? payload.nutrition : {}) as Record<string, unknown>;
  const numOrNull = (val: unknown, max: number): number | null => {
    if (val === null || val === undefined || val === "") return null;
    const n = Number(val);
    return Number.isFinite(n) && n >= 0 && n <= max ? Math.round(n * 1000) / 1000 : null;
  };
  const calories = numOrNull(nut.energyKcalPer100g ?? nut.calories, 1000);
  const protein = numOrNull(nut.proteinGPer100g ?? nut.protein, 100);
  const carbs = numOrNull(nut.carbohydratesGPer100g ?? nut.carbs, 100);
  const sugar = numOrNull(nut.sugarGPer100g ?? nut.sugar, 100);
  const fat = numOrNull(nut.fatGPer100g ?? nut.fat, 100);
  const fiber = numOrNull(nut.fiberGPer100g ?? nut.fiber, 100);
  const sodium = numOrNull(nut.sodiumMgPer100g ?? nut.sodium, 100000);
  const strList = (val: unknown) =>
    Array.isArray(val)
      ? val.map((v) => cleanText(v, 80).toLowerCase()).filter(Boolean).slice(0, 60)
      : [];

  return {
    barcode,
    name,
    brand,
    category,
    ingredientsText,
    ingredients: ingredientsText
      ? ingredientsText.split(",").map((s) => s.trim()).filter(Boolean).slice(0, 100)
      : strList(payload.ingredients),
    allergens: strList(payload.allergens),
    traces: strList(payload.traces),
    additives: strList(payload.additives),
    nutriscore: cleanText(payload.nutriscore, 2).toLowerCase() || null,
    nutrition: {
      energyKcalPer100g: calories,
      proteinGPer100g: protein,
      carbohydratesGPer100g: carbs,
      sugarGPer100g: sugar,
      fatGPer100g: fat,
      fiberGPer100g: fiber,
      sodiumMgPer100g: sodium,
      calories,
      protein,
      carbs,
      sugar,
      fat,
      fiber,
      sodium,
    },
    schemaVersion: 2,
    adminVerified: true,
    adminVerifiedBy: admin.email || admin.uid,
    adminVerifiedAt: new Date().toISOString(),
  };
}

export async function runAdminAction(request: AdminActionRequest, overrides: AdminDeps = {}): Promise<Record<string, any>> {
  const admin = assertAdmin(request.auth);
  const deps = defaultDeps(overrides);
  const body = (request.data ?? {}) as Record<string, any>;
  const action = cleanText(body.action, 64);

  switch (action) {
    case "overview": {
      const today = new Date().toISOString().slice(0, 10);
      const [flags, health, abuse, reports, deletions, quotas, audits] = await Promise.all([
        deps.readFlags(),
        sbRest(deps, "ai_provider_health?select=*").catch(() => []),
        sbRest(deps, "ai_abuse_events?select=id,severity,category,created_at&order=created_at.desc&limit=50").catch(() => []),
        sbRest(deps, "product_reports?status=eq.open&select=id").catch(() => []),
        sbRest(deps, "deletion_requests?status=eq.pending&select=id").catch(() => []),
        sbRest(deps, `ai_user_quotas?day_date=eq.${today}&select=user_id,task,daily_count`).catch(() => []),
        sbRest(deps, "admin_audit_logs?select=id&limit=100").catch(() => []),
      ]);
      const aiRequestsToday = Array.isArray(quotas)
        ? quotas.reduce((sum: number, q: any) => sum + (Number(q.daily_count) || 0), 0)
        : 0;
      const activeQuotaUsersToday = Array.isArray(quotas)
        ? new Set(quotas.map((q: any) => q.user_id)).size
        : 0;
      return {
        flags,
        providerHealth: health ?? [],
        metrics: {
          recentAbuseCount: Array.isArray(abuse) ? abuse.length : 0,
          openReportsCount: Array.isArray(reports) ? reports.length : 0,
          pendingDeletionsCount: Array.isArray(deletions) ? deletions.length : 0,
          aiRequestsToday,
          activeQuotaUsersToday,
          auditEntriesSampled: Array.isArray(audits) ? audits.length : 0,
        },
        admin: { uid: admin.uid, email: admin.email },
      };
    }

    case "getConfig": {
      const flags = await deps.readFlags();
      return { flags };
    }

    case "updateConfig": {
      const patch = sanitizeFlagPatch((body.patch ?? {}) as Record<string, unknown>);
      await deps.writeFlags({ ...patch, updatedBy: admin.email || admin.uid, updatedAt: new Date().toISOString() });
      await writeAuditLog(deps, admin, "update_config", "config", "featureFlags", patch);
      return { flags: await deps.readFlags() };
    }

    case "getQuotasAndHealth": {
      const [flags, health, quotas, ipLimits] = await Promise.all([
        deps.readFlags(),
        sbRest(deps, "ai_provider_health?select=*"),
        sbRest(deps, "ai_user_quotas?select=*&order=day_date.desc,daily_count.desc&limit=50"),
        sbRest(deps, "ai_ip_rate_limits?select=*&order=window_start.desc&limit=30"),
      ]);
      return { flags, health, quotas, ipLimits };
    }

    case "resetProviderCircuit": {
      const provider = cleanText(body.provider, 20);
      if (provider !== "groq" && provider !== "gemini") {
        throw new HttpsError("invalid-argument", "Provider must be 'groq' or 'gemini'.");
      }
      resetProviderCircuitsForTest();
      await sbRest(deps, `ai_provider_health?provider=eq.${provider}`, {
        method: "PATCH",
        prefer: "return=minimal",
        body: {
          cooldown_until: null,
          consecutive_failures: 0,
          last_status: null,
          last_error_at: null,
          updated_at: new Date().toISOString(),
        },
      });
      await writeAuditLog(deps, admin, "reset_provider_circuit", "provider", provider, {});
      return { ok: true, provider };
    }

    case "resetUserQuota": {
      const userId = cleanText(body.userId, 128);
      const task = cleanText(body.task, 32);
      if (!userId) throw new HttpsError("invalid-argument", "userId is required.");
      const filter = task && TASK_KEYS.includes(task as AiTask)
        ? `user_id=eq.${encodeURIComponent(userId)}&task=eq.${encodeURIComponent(task)}`
        : `user_id=eq.${encodeURIComponent(userId)}`;
      await sbRest(deps, `ai_user_quotas?${filter}`, {
        method: "PATCH",
        prefer: "return=minimal",
        body: { daily_count: 0, last_request_at: null },
      });
      await writeAuditLog(deps, admin, "reset_user_quota", "user", userId, { task: task || "all" });
      return { ok: true };
    }

    case "listAbuseEvents": {
      const severity = cleanText(body.severity, 16);
      const userId = cleanText(body.userId, 128);
      const clauses = ["select=*", "order=created_at.desc", "limit=100"];
      if (severity && ["low", "medium", "high"].includes(severity)) {
        clauses.push(`severity=eq.${encodeURIComponent(severity)}`);
      }
      if (userId) clauses.push(`user_id=eq.${encodeURIComponent(userId)}`);
      const events = await sbRest(deps, `ai_abuse_events?${clauses.join("&")}`);
      return { events };
    }

    case "lookupUser": {
      const uidInput = cleanText(body.uid, 128);
      const emailInput = cleanText(body.email, 320);
      if (!uidInput && !emailInput) {
        throw new HttpsError("invalid-argument", "Provide either uid or email.");
      }
      const authUser = await deps.lookupAuthUser({ uid: uidInput || undefined, email: emailInput || undefined });
      const resolvedUid = authUser?.uid || uidInput;
      if (!resolvedUid) throw new HttpsError("not-found", "User account not found.");
      const encUid = encodeURIComponent(resolvedUid);
      const [profiles, consents, quotas, abuse, suspensionRow, suspensionDoc, deleting] = await Promise.all([
        sbRest(deps, `profiles?user_id=eq.${encUid}&id=eq.profile&deleted=eq.false&select=data,updated_at&limit=1`).catch(() => []),
        sbRest(deps, `user_consents?user_id=eq.${encUid}&select=*&order=accepted_at.desc&limit=5`).catch(() => []),
        sbRest(deps, `ai_user_quotas?user_id=eq.${encUid}&select=*`).catch(() => []),
        sbRest(deps, `ai_abuse_events?user_id=eq.${encUid}&select=*&order=created_at.desc&limit=20`).catch(() => []),
        sbRest(deps, `user_suspensions?user_id=eq.${encUid}&select=*&limit=1`).catch(() => []),
        deps.readSuspensionDoc(resolvedUid),
        deps.readDeletionGuard(resolvedUid),
      ]);
      return {
        authUser,
        uid: resolvedUid,
        profile: profiles[0]?.data ?? null,
        consents,
        quotas,
        abuseEvents: abuse,
        suspended: Boolean(suspensionDoc?.active === true || suspensionRow[0]?.active === true || authUser?.disabled === true),
        suspension: suspensionRow[0] ?? suspensionDoc ?? null,
        deletionInProgress: deleting,
      };
    }

    case "toggleUserSuspension": {
      const targetUid = cleanText(body.userId, 128);
      const suspend = body.suspend === true;
      const reason = cleanText(body.reason, 400) || (suspend ? "Suspended by administrator" : "Restored by administrator");
      if (!targetUid) throw new HttpsError("invalid-argument", "userId is required.");
      if (targetUid === admin.uid) {
        throw new HttpsError("failed-precondition", "You cannot suspend your own active admin account.");
      }
      await deps.updateAuthDisabled(targetUid, suspend);
      await deps.setSuspensionDoc(targetUid, suspend, reason, admin.uid);
      await sbRest(deps, "user_suspensions?on_conflict=user_id", {
        method: "POST",
        prefer: "resolution=merge-duplicates,return=minimal",
        body: {
          user_id: targetUid,
          active: suspend,
          reason,
          updated_by: admin.email || admin.uid,
          updated_at: new Date().toISOString(),
        },
      });
      await writeAuditLog(deps, admin, suspend ? "suspend_user" : "unsuspend_user", "user", targetUid, { reason });
      return { ok: true, suspended: suspend };
    }

    case "deleteUserAccount": {
      const targetUid = cleanText(body.userId, 128);
      const confirmUid = cleanText(body.confirmUid, 128);
      const deletionRequestId = cleanText(body.deletionRequestId, 64);
      if (!targetUid || confirmUid !== targetUid) {
        throw new HttpsError("invalid-argument", "Confirmation UID must match target userId.");
      }
      if (targetUid === admin.uid) {
        throw new HttpsError("failed-precondition", "Cannot delete your own admin account from the portal.");
      }
      await deps.purgeUser(targetUid);
      try {
        await deps.deleteAuthUser(targetUid);
      } catch (err: any) {
        if (err?.code !== "auth/user-not-found") throw err;
      }
      if (deletionRequestId) {
        await sbRest(deps, `deletion_requests?id=eq.${encodeURIComponent(deletionRequestId)}`, {
          method: "PATCH",
          prefer: "return=minimal",
          body: {
            status: "completed",
            resolved_by: admin.email || admin.uid,
            resolution_note: "Purged via admin portal",
            resolved_at: new Date().toISOString(),
          },
        });
      }
      await writeAuditLog(deps, admin, "delete_user_account", "user", targetUid, { deletionRequestId: deletionRequestId || null });
      return { deleted: true, uid: targetUid };
    }

    case "listDeletionRequests": {
      const status = cleanText(body.status, 24);
      const clauses = ["select=*", "order=created_at.desc", "limit=100"];
      if (status && ["pending", "completed", "rejected"].includes(status)) {
        clauses.push(`status=eq.${status}`);
      }
      const requests = await sbRest(deps, `deletion_requests?${clauses.join("&")}`);
      return { requests };
    }

    case "createDeletionRequest": {
      const requestEmail = cleanText(body.requestEmail, 320);
      let targetUid = cleanText(body.targetUid, 128);
      const source = ["web_email", "support", "admin"].includes(String(body.source)) ? String(body.source) : "web_email";
      const notes = cleanText(body.notes, 600);
      if (!requestEmail && !targetUid) {
        throw new HttpsError("invalid-argument", "Provide requestEmail or targetUid.");
      }
      if (!targetUid && requestEmail) {
        const found = await deps.lookupAuthUser({ email: requestEmail });
        if (found?.uid) targetUid = String(found.uid);
      }
      const created = await sbRest(deps, "deletion_requests", {
        method: "POST",
        prefer: "return=representation",
        body: { request_email: requestEmail, target_uid: targetUid, source, notes, status: "pending" },
      });
      await writeAuditLog(deps, admin, "create_deletion_request", "deletion_request", String(created?.[0]?.id ?? ""), { requestEmail, targetUid, source });
      return { request: created?.[0] ?? null };
    }

    case "resolveDeletionRequest": {
      const id = cleanText(body.id, 64);
      const status = body.status === "completed" ? "completed" : body.status === "rejected" ? "rejected" : "";
      const note = cleanText(body.resolutionNote, 500);
      if (!id || !status) throw new HttpsError("invalid-argument", "Valid request id and status required.");
      await sbRest(deps, `deletion_requests?id=eq.${encodeURIComponent(id)}`, {
        method: "PATCH",
        prefer: "return=minimal",
        body: {
          status,
          resolution_note: note,
          resolved_by: admin.email || admin.uid,
          resolved_at: new Date().toISOString(),
        },
      });
      await writeAuditLog(deps, admin, "resolve_deletion_request", "deletion_request", id, { status, note });
      return { ok: true };
    }

    case "listProductReports": {
      const status = cleanText(body.status, 24);
      const clauses = ["select=*", "order=created_at.desc", "limit=100"];
      if (status && ["open", "resolved", "dismissed"].includes(status)) {
        clauses.push(`status=eq.${status}`);
      }
      const reports = await sbRest(deps, `product_reports?${clauses.join("&")}`);
      return { reports };
    }

    case "resolveProductReport": {
      const id = cleanText(body.id, 64);
      const status = body.status === "resolved" ? "resolved" : body.status === "dismissed" ? "dismissed" : "";
      const note = cleanText(body.resolutionNote, 500);
      if (!id || !status) throw new HttpsError("invalid-argument", "Valid report id and status required.");
      await sbRest(deps, `product_reports?id=eq.${encodeURIComponent(id)}`, {
        method: "PATCH",
        prefer: "return=minimal",
        body: {
          status,
          resolution_note: note,
          resolved_by: admin.email || admin.uid,
          resolved_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      });
      await writeAuditLog(deps, admin, "resolve_product_report", "product_report", id, { status, note });
      return { ok: true };
    }

    case "getCanonicalProduct": {
      const barcode = cleanText(body.barcode, 20);
      if (!BARCODE_PATTERN.test(barcode)) throw new HttpsError("invalid-argument", "Enter an 8–14 digit barcode.");
      const [product, reports] = await Promise.all([
        deps.readProduct(barcode),
        sbRest(deps, `product_reports?barcode=eq.${barcode}&select=*&order=created_at.desc&limit=20`).catch(() => []),
      ]);
      return { barcode, product, reports };
    }

    case "saveCanonicalProduct": {
      const barcode = cleanText(body.barcode, 20);
      if (!BARCODE_PATTERN.test(barcode)) throw new HttpsError("invalid-argument", "Enter an 8–14 digit barcode.");
      const sanitized = sanitizeCanonicalProductPatch(barcode, (body.product ?? {}) as Record<string, unknown>, admin);
      await deps.writeProduct(barcode, sanitized);
      const reportId = cleanText(body.resolveReportId, 64);
      if (reportId) {
        await sbRest(deps, `product_reports?id=eq.${encodeURIComponent(reportId)}`, {
          method: "PATCH",
          prefer: "return=minimal",
          body: {
            status: "resolved",
            resolution_note: "Canonical product verified in admin catalog",
            resolved_by: admin.email || admin.uid,
            resolved_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
        });
      }
      await writeAuditLog(deps, admin, "save_canonical_product", "product", barcode, { name: sanitized.name, resolveReportId: reportId || null });
      return { product: sanitized };
    }

    case "listAdditiveOverrides": {
      const additives = await sbRest(deps, "food_additives_overrides?select=*&order=ins.asc&limit=300");
      return { additives };
    }

    case "upsertAdditiveOverride": {
      const ins = cleanText(body.ins, 24).toLowerCase();
      const name = cleanText(body.name, 160);
      const category = cleanText(body.category, 80) || "Additive";
      const tier = ["low", "caution", "avoid", "info"].includes(String(body.safetyTier)) ? String(body.safetyTier) : "caution";
      const summary = cleanText(body.summary, 600);
      const dietaryNotes = cleanText(body.dietaryNotes, 300);
      const active = body.active !== false;
      if (!ins || !name) throw new HttpsError("invalid-argument", "INS code and name are required.");
      const rows = await sbRest(deps, "food_additives_overrides?on_conflict=ins", {
        method: "POST",
        prefer: "resolution=merge-duplicates,return=representation",
        body: {
          ins,
          name,
          category,
          safety_tier: tier,
          summary,
          dietary_notes: dietaryNotes,
          active,
          updated_by: admin.email || admin.uid,
          updated_at: new Date().toISOString(),
        },
      });
      await writeAuditLog(deps, admin, "upsert_additive_override", "additive", ins, { name, safetyTier: tier, active });
      return { additive: rows?.[0] ?? null };
    }

    case "deleteAdditiveOverride": {
      const ins = cleanText(body.ins, 24).toLowerCase();
      if (!ins) throw new HttpsError("invalid-argument", "INS code is required.");
      await sbRest(deps, `food_additives_overrides?ins=eq.${encodeURIComponent(ins)}`, {
        method: "DELETE",
        prefer: "return=minimal",
      });
      await writeAuditLog(deps, admin, "delete_additive_override", "additive", ins, {});
      return { deleted: true, ins };
    }

    case "listAuditLogs": {
      const logs = await sbRest(deps, "admin_audit_logs?select=*&order=created_at.desc&limit=100");
      return { logs };
    }

    default:
      throw new HttpsError("invalid-argument", "Unsupported admin action.");
  }
}

export const adminAction = {
  run: (request: AdminActionRequest) => runAdminAction(request),
};
