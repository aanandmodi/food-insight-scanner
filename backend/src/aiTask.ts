import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Buffer } from "node:buffer";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { requestAi } from "./aiProvider";
import { aiMessages } from "./aiMessages";
import { macroBaseline, validateMacroAdjustment } from "./macroSafety";
import { AiTask, limits, boundedString, validateOutput, requiresEmailVerification } from "./aiValidation";
import {
  inspectPromptShield,
  moderateWithLlamaGuard,
  recordAbuseEvent,
  sanitizeUntrustedText,
} from "./promptShield";
import { resolveServerContext } from "./serverContext";
import { enforceOutputSafety } from "./outputSafety";
import { groqApiKey, readSecretOrEnv, supabaseAdminKey } from "./secrets";

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
    ...(typeof product.name === "string" ? { name: boundedString(product.name, 160, true) } : {}),
    ...(typeof product.nutriscore === "string" ? { nutriscore: product.nutriscore } : {}),
    ...(typeof product.novaGroup === "number" ? { novaGroup: product.novaGroup } : {}),
    ...(typeof product.ingredientsText === "string" ? { ingredientsText: boundedString(product.ingredientsText, 1600, true) } : {}),
    ...(Array.isArray(product.allergens) ? { allergens: product.allergens.slice(0, 30) } : {}),
    ...(Array.isArray(product.traces) ? { traces: product.traces.slice(0, 30) } : {}),
    ...(product.nutrition && typeof product.nutrition === "object" ? { nutrition: product.nutrition } : {}),
  };
}

export const aiTask = onCall({
  region: "asia-south1",
  timeoutSeconds: 60,
  enforceAppCheck: true,
  secrets: [groqApiKey, supabaseAdminKey],
  maxInstances: 10,
}, async (request) => {
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
  let authoritative;
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

  // Layer 3: Strict role separation + delimited untrusted data envelope built from authoritative context.
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

  const configuredLimit = config.aiDailyLimits?.[task];
  let dailyLimit = Number.isInteger(configuredLimit) && configuredLimit >= 0 && configuredLimit <= 200
    ? configuredLimit : limits[task];
  if (request.auth.token.firebase?.sign_in_provider === "anonymous") {
    dailyLimit = Math.min(dailyLimit, task === "plan" ? 1 : 5);
  }

  const day = new Date().toISOString().slice(0, 10);
  const quota = db.doc(`users/${request.auth.uid}/aiUsage/current`);
  const globalQuota = db.doc("serviceLimits/aiBudget");
  await db.runTransaction(async (transaction) => {
    const data = (await transaction.get(quota)).data() ?? {};
    const globalData = (await transaction.get(globalQuota)).data() ?? {};
    if (Number(globalData.cooldownUntil) > Date.now()) {
      throw new HttpsError(
        "resource-exhausted",
        "AI capacity is busy. Your scans and Food Fit still work. Please try again shortly.",
        { reason: "provider", retryAfterSeconds: Math.ceil((Number(globalData.cooldownUntil) - Date.now()) / 1000) },
      );
    }
    const total = globalData.day === day ? Number(globalData.count) || 0 : 0;
    const minute = Math.floor(Date.now() / 60000);
    const minuteCount = globalData.minute === minute ? Number(globalData.minuteCount) || 0 : 0;
    // Global caps also bound abuse through repeated anonymous account creation.
    const globalLimit = Number.isInteger(config.aiGlobalDailyLimit)
      ? Math.max(0, Math.min(200, config.aiGlobalDailyLimit)) : 200;
    if (total >= globalLimit || minuteCount >= 10) {
      throw new HttpsError("resource-exhausted", "AI capacity is reached. Please retry later.");
    }
    const count = data.day === day ? Number(data[task]) || 0 : 0;
    const lastRequestAt = Number(task === "quickReplies" ? data.lastQuickReplyAt : data.lastRequestAt) || 0;
    if (count >= dailyLimit) {
      throw new HttpsError("resource-exhausted", "Daily AI limit reached. Try again tomorrow.", { reason: "daily-quota" });
    }
    if (Date.now() - lastRequestAt < 2000) {
      throw new HttpsError("resource-exhausted", "Please wait a moment before another request.", { reason: "burst" });
    }
    transaction.set(quota, {
      ...(data.day === day ? data : {}),
      day,
      [task]: count + 1,
      [task === "quickReplies" ? "lastQuickReplyAt" : "lastRequestAt"]: Date.now(),
    });
    transaction.set(globalQuota, { day, count: total + 1, minute, minuteCount: minuteCount + 1 });
  });

  // Charge attempts, including provider failures, to bound cost under repeated retries.
  try {
    const result = await requestAi(task, aiApiKey, messages);
    const validated = validateOutput(task, result);
    const targetValidated = task === "macros"
      ? validateMacroAdjustment(validated, authoritative.contextForModel, config.macroMaxAdjustmentPercent)
      : validated;

    // Layer 4: Deterministic Allergen & Safety Output Cross-Check.
    const safetyEvaluation = enforceOutputSafety(
      task,
      targetValidated,
      {
        allergies: authoritative.profileForModel.allergies,
        dietaryPreferences: authoritative.profileForModel.dietaryPreferences,
        diseases: authoritative.diseasesForSafety,
      },
      authoritative.foodFit ?? undefined,
    );

    if (safetyEvaluation.blocked) {
      await recordAbuseEvent(
        {
          userId: request.auth.uid,
          task,
          category: "unsafe_output",
          severity: "high",
          ruleId: safetyEvaluation.ruleId || "output-safety-conflict",
          snippet: safetyEvaluation.reason || "Output conflicted with user safety rules",
        },
        { serviceRoleKey },
      );
      throw new HttpsError(
        "failed-precondition",
        safetyEvaluation.reason || "This suggestion conflicted with your dietary or allergy settings. Please retry.",
      );
    }

    if (safetyEvaluation.safetyFlags.some((f) => f.includes("removed") || f.includes("override"))) {
      await recordAbuseEvent(
        {
          userId: request.auth.uid,
          task,
          category: "unsafe_output",
          severity: "medium",
          ruleId: safetyEvaluation.safetyFlags.join(",").slice(0, 64),
          snippet: "AI output adjusted by server safety cross-check",
        },
        { serviceRoleKey },
      );
    }

    return safetyEvaluation.value;
  } catch (error) {
    if (error instanceof HttpsError && error.code === "resource-exhausted") {
      const details = error.details as { reason?: string; retryAfterSeconds?: number } | undefined;
      if (details?.reason === "provider") {
        await globalQuota.set({ cooldownUntil: Date.now() + Math.max(1, Math.min(86400, details.retryAfterSeconds ?? 60)) * 1000 }, { merge: true });
      }
    }
    if (error instanceof HttpsError) throw error;
    // Neither model output nor user health data is logged.
    throw new HttpsError("unavailable", "AI could not complete this request. Please retry later.");
  }
});
