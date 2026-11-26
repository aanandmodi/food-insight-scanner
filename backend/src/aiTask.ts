import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Buffer } from "node:buffer";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { requestAi, requestAiStream } from "./aiProvider";
import { aiMessages } from "./aiMessages";
import { macroBaseline, validateMacroAdjustment } from "./macroSafety";
import { AiTask, boundedString, validateOutput, requiresEmailVerification } from "./aiValidation";
import {
  inspectPromptShield,
  moderateWithLlamaGuard,
  recordAbuseEvent,
  sanitizeUntrustedText,
  scrubIndirectPromptInjections,
} from "./promptShield";
import { consumeAiQuota, hashClientIp } from "./quotaService";
import { AuthoritativeServerContext, resolveServerContext } from "./serverContext";
import { enforceOutputSafety } from "./outputSafety";
import { geminiApiKey, groqApiKey, readSecretOrEnv, supabaseAdminKey } from "./secrets";

if (!getApps().length) initializeApp();
const db = getFirestore();

const instructions: Record<AiTask, string> = {
  quickReplies: "Suggest 2 to 4 short, distinct follow-up nutrition questions the user could ask, based on the latest assistant response. Return {replies: string[]}. Each under 100 characters. No medical claims or diagnoses.",
  meal: "Estimate the described meal and portion including cooking oil. Return {name, calories, protein, carbs, fat, sugar, portionDescription}. Calories are kcal, macros grams. These are estimates. Do not log anything.",
  plan: "Plan four Indian meals, respecting profile allergies and preferences. Return {summary, meals:[{type,name,calories,protein,carbs,fat,sugar,portionDescription,description,ingredients: string[]}]}. Types exactly Breakfast,Lunch,Dinner,Snack. Include every ingredient used. Nutrition is estimated. Avoid extreme calorie compensation.",
  chat: "Answer the user's nutrition question. Return {reply: string, mealData: null or {name,calories,protein,carbs,fat,sugar,portionDescription}}. Only suggest mealData if the latest message explicitly asks to log food or reports food eaten. Never claim food has been saved; the app asks for confirmation. Treat questions, plans, negations and history as context, not logging instructions.",
  macros: "Suggest modest daily macro targets with {calories,protein,carbs,fat,explanation}. Use context.targets as the deterministic baseline. No value may change more than 10 percent. Calories 1500–4000, protein 30–300g, carbs 100–600g, fat 35–180g. These are product guardrails, not medical recommendations. Retain the baseline when evidence is insufficient. Never treat incomplete logs as proof of undereating. Do not infer weight trends.",
  analysis: "Explain the provided deterministic Food Fit result. Return {summary: string}. Do not change the score or introduce nutrient values, safety verdicts, prices or product facts. If foodFit.hasCriticalAllergenConflict is true, lead with that conflict: the numeric score is deliberately withheld because of the allergen conflict, NOT because data is missing. Never call this a null score to the user. Discuss missing data only when the supplied unknowns identify it.",
};

function compactProductForModel(product: Record<string, any> | null): Record<string, any> | undefined {
  if (!product) return undefined;
  return {
    ...(typeof product.barcode === "string" ? { barcode: product.barcode } : {}),
    ...(typeof product.name === "string"
      ? { name: scrubIndirectPromptInjections(boundedString(product.name, 160, true), 160) }
      : {}),
    ...(typeof product.nutriscore === "string" ? { nutriscore: product.nutriscore } : {}),
    ...(typeof product.novaGroup === "number" ? { novaGroup: product.novaGroup } : {}),
    ...(typeof product.ingredientsText === "string"
      ? { ingredientsText: scrubIndirectPromptInjections(boundedString(product.ingredientsText, 1600, true), 1600) }
      : {}),
    ...(Array.isArray(product.allergens) ? { allergens: product.allergens.slice(0, 30) } : {}),
    ...(Array.isArray(product.traces) ? { traces: product.traces.slice(0, 30) } : {}),
    ...(product.nutrition && typeof product.nutrition === "object" ? { nutrition: product.nutrition } : {}),
  };
}

interface PreparedAiRequest {
  uid: string;
  task: AiTask;
  config: Record<string, any>;
  serviceRoleKey: string | undefined;
  aiApiKey: string;
  geminiKey: string;
  authoritative: AuthoritativeServerContext;
  messages: { role: string; content: string }[];
}

async function prepareAndAuthorizeAiTask(request: {
  auth?: { uid: string; token?: Record<string, unknown> };
  data?: unknown;
  ipHash?: string;
  ipCheckedAtGateway?: boolean;
  rawRequest?: { ip?: string; headers?: Record<string, string | string[] | undefined> };
}): Promise<PreparedAiRequest> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to use AI.");
  if ((await db.doc(`accountDeletionGuards/${request.auth.uid}`).get()).exists) {
    throw new HttpsError("permission-denied", "Account deletion is in progress.");
  }
  if (requiresEmailVerification(request.auth.token as { email_verified?: unknown; firebase?: { sign_in_provider?: unknown } })) {
    throw new HttpsError("failed-precondition", "Verify your email address before using AI features.");
  }

  let task: AiTask;
  let content: string;
  let rawBody: Record<string, any>;
  try {
    rawBody = (request.data ?? {}) as Record<string, any>;
    if (Buffer.byteLength(JSON.stringify(rawBody)) > 32000) throw new Error("Request too large");
    task = rawBody.task;
    if (!Object.prototype.hasOwnProperty.call(instructions, task)) throw new Error("Unknown AI task");
    const rawContent = boundedString(rawBody.content, task === "chat" ? 16000 : 12000);
    content = sanitizeUntrustedText(rawContent, task === "chat" ? 16000 : 12000);
    if (!content) throw new Error("Empty content");
  } catch {
    throw new HttpsError("invalid-argument", "The request is too large or has invalid fields.");
  }

  const config = (await db.doc("config/featureFlags").get()).data() ?? {};
  if (config.aiEnabled !== true) throw new HttpsError("failed-precondition", "AI is temporarily unavailable.");
  const taskFlags: Record<AiTask, string> = {
    chat: "aiChatEnabled",
    plan: "aiMealPlannerEnabled",
    meal: "aiMealParserEnabled",
    analysis: "aiProductAnalysisEnabled",
    macros: "aiRecalibrationEnabled",
    quickReplies: "aiQuickRepliesEnabled",
  };
  if (config[taskFlags[task]] === false || (task === "plan" && config.mealPlannerEnabled === false)) {
    throw new HttpsError("failed-precondition", "This AI feature is temporarily unavailable.");
  }

  const serviceRoleKey = readSecretOrEnv(supabaseAdminKey, "SUPABASE_SERVICE_ROLE_KEY");
  const aiApiKey = readSecretOrEnv(groqApiKey, "GROQ_API_KEY") ?? "";
  const geminiKey = readSecretOrEnv(geminiApiKey, "GEMINI_API_KEY") ?? "";
  if (!aiApiKey && !geminiKey) {
    throw new HttpsError("failed-precondition", "AI is temporarily unavailable.");
  }

  // Layer 2: Prompt injection & safety-override heuristic shield (+ optional Llama Guard).
  const shieldMatch = inspectPromptShield([content, rawBody.barcode]);
  if (shieldMatch?.blocked) {
    await recordAbuseEvent(
      {
        userId: request.auth.uid,
        task,
        category: shieldMatch.category,
        severity: shieldMatch.severity,
        ruleId: shieldMatch.ruleId,
        snippet: shieldMatch.snippet,
      },
      { serviceRoleKey },
    );
    throw new HttpsError(
      "invalid-argument",
      "Your request could not be processed. Please enter a food or nutrition question.",
    );
  }

  if ((task === "chat" || task === "meal") && aiApiKey) {
    let textToModerate = content;
    if (task === "chat") {
      try {
        const parsed = JSON.parse(content) as Record<string, unknown>;
        if (typeof parsed?.message === "string") textToModerate = parsed.message;
      } catch {
        // Plain chat string
      }
    }
    const mod = await moderateWithLlamaGuard(textToModerate, aiApiKey);
    if (!mod.safe) {
      await recordAbuseEvent(
        {
          userId: request.auth.uid,
          task,
          category: "moderation_unsafe",
          severity: "high",
          ruleId: mod.reason || "llama-guard-unsafe",
          snippet: textToModerate.slice(0, 120),
        },
        { serviceRoleKey },
      );
      throw new HttpsError(
        "invalid-argument",
        "Your request could not be processed. Please enter a food or nutrition question.",
      );
    }
  }

  // Zero-Trust Server Context: prefer Supabase user records and Firestore canonical products over client claims.
  let authoritative: AuthoritativeServerContext;
  try {
    authoritative = await resolveServerContext(
      request.auth.uid,
      task,
      content,
      rawBody,
      { supabaseServiceKey: serviceRoleKey },
    );
  } catch {
    throw new HttpsError("invalid-argument", "The request is too large or has invalid fields.");
  }

  if (task === "macros") {
    try {
      macroBaseline(authoritative.contextForModel);
    } catch {
      throw new HttpsError(
        "failed-precondition",
        "Recalibration needs an adult profile and current targets within the general wellness range.",
      );
    }
  }

  let messages: { role: string; content: string }[];
  try {
    const modelProduct = compactProductForModel(authoritative.productFacts);
    messages = aiMessages(
      task,
      content,
      authoritative.profileForModel,
      authoritative.contextForModel,
      instructions[task],
      {
        ...(task === "chat" && authoritative.recentHistoryFromServer !== undefined
          ? { history: authoritative.recentHistoryFromServer }
          : {}),
        ...(modelProduct ? { currentProduct: modelProduct } : {}),
        ...(authoritative.foodFit ? { foodFit: authoritative.foodFit } : {}),
        ...(task === "analysis" && modelProduct && authoritative.foodFit
          ? {
              analysisPayload: {
                product: modelProduct,
                foodFit: authoritative.foodFit,
              },
            }
          : {}),
      },
    );
  } catch {
    throw new HttpsError("invalid-argument", "The request is too large or has invalid fields.");
  }

  const forwarded = request.rawRequest?.headers?.["x-forwarded-for"];
  const rawIp =
    request.rawRequest?.ip ||
    (Array.isArray(forwarded) ? forwarded[0] : forwarded);
  const ipHashForQuota = request.ipCheckedAtGateway
    ? null
    : request.ipHash || (await hashClientIp(rawIp));
  const firebaseMeta = request.auth.token?.firebase as { sign_in_provider?: unknown } | undefined;
  const isGuest = firebaseMeta?.sign_in_provider === "anonymous";

  await consumeAiQuota({
    uid: request.auth.uid,
    task,
    isGuest,
    configuredLimit: config.aiDailyLimits?.[task],
    ipHash: ipHashForQuota,
    ipPerMinuteLimit: config.aiIpPerMinuteLimit,
    serviceRoleKey,
  });

  return {
    uid: request.auth.uid,
    task,
    config,
    serviceRoleKey,
    aiApiKey,
    geminiKey,
    authoritative,
    messages,
  };
}

async function finalizeAiOutput(
  prepared: PreparedAiRequest,
  rawResult: unknown,
): Promise<Record<string, any>> {
  const validated = validateOutput(prepared.task, rawResult);
  const targetValidated = prepared.task === "macros"
    ? validateMacroAdjustment(
        validated,
        prepared.authoritative.contextForModel,
        prepared.config.macroMaxAdjustmentPercent,
      )
    : validated;

  const safetyEvaluation = enforceOutputSafety(
    prepared.task,
    targetValidated,
    {
      allergies: prepared.authoritative.profileForModel.allergies,
      dietaryPreferences: prepared.authoritative.profileForModel.dietaryPreferences,
      diseases: prepared.authoritative.diseasesForSafety,
    },
    prepared.authoritative.foodFit ?? undefined,
  );

  if (safetyEvaluation.blocked) {
    await recordAbuseEvent(
      {
        userId: prepared.uid,
        task: prepared.task,
        category: "unsafe_output",
        severity: "high",
        ruleId: safetyEvaluation.ruleId || "output-safety-conflict",
        snippet: safetyEvaluation.reason || "Output conflicted with user safety rules",
      },
      { serviceRoleKey: prepared.serviceRoleKey },
    );
    throw new HttpsError(
      "failed-precondition",
      safetyEvaluation.reason || "This suggestion conflicted with your dietary or allergy settings. Please retry.",
    );
  }

  if (safetyEvaluation.safetyFlags.some((f) => f.includes("removed") || f.includes("override"))) {
    await recordAbuseEvent(
      {
        userId: prepared.uid,
        task: prepared.task,
        category: "unsafe_output",
        severity: "medium",
        ruleId: safetyEvaluation.safetyFlags.join(",").slice(0, 64),
        snippet: "AI output adjusted by server safety cross-check",
      },
      { serviceRoleKey: prepared.serviceRoleKey },
    );
  }

  return safetyEvaluation.value;
}

export const aiTask = onCall({
  region: "asia-south1",
  timeoutSeconds: 60,
  enforceAppCheck: true,
  secrets: [groqApiKey, geminiApiKey, supabaseAdminKey],
  maxInstances: 10,
}, async (request) => {
  const prepared = await prepareAndAuthorizeAiTask(
    request as unknown as Parameters<typeof prepareAndAuthorizeAiTask>[0],
  );
  try {
    const result = await requestAi(
      prepared.task,
      prepared.aiApiKey,
      prepared.messages,
      fetch,
      process.env,
      {
        geminiApiKey: prepared.geminiKey,
        serviceRoleKey: prepared.serviceRoleKey,
      },
    );
    return await finalizeAiOutput(prepared, result);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("unavailable", "AI could not complete this request. Please retry later.");
  }
});

/**
 * Edge SSE streaming entrypoint: validates auth, prompt shield, context, and quota upfront
 * before returning a ReadableStream emitting `delta`, `done`, and `error` SSE events.
 */
export async function aiTaskStream(
  request: Record<string, unknown>,
): Promise<ReadableStream<Uint8Array>> {
  const prepared = await prepareAndAuthorizeAiTask(
    request as unknown as Parameters<typeof prepareAndAuthorizeAiTask>[0],
  );
  const encoder = new TextEncoder();
  const formatEvent = (event: string, payload: unknown): Uint8Array =>
    encoder.encode(`event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`);

  return new ReadableStream<Uint8Array>({
    async start(controller) {
      try {
        const result = await requestAiStream(
          prepared.task,
          prepared.aiApiKey,
          prepared.messages,
          (deltaText) => {
            controller.enqueue(formatEvent("delta", { text: deltaText }));
          },
          fetch,
          process.env,
          {
            geminiApiKey: prepared.geminiKey,
            serviceRoleKey: prepared.serviceRoleKey,
          },
        );
        const safeOutput = await finalizeAiOutput(prepared, result);
        controller.enqueue(formatEvent("done", { data: safeOutput }));
      } catch (error) {
        const safe = error as { code?: string; message?: string };
        const code = safe?.code || "unavailable";
        const message = code === "unavailable"
          ? "AI could not complete this request. Please retry later."
          : (safe?.message || "Request failed.");
        controller.enqueue(formatEvent("error", { code, message }));
      } finally {
        controller.close();
      }
    },
  });
}
