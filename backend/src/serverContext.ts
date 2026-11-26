import { getFirestore } from "firebase-admin/firestore";
import { nutritionContext } from "./aiContext";
import { AiTask, boundedString, profileData } from "./aiValidation";
import { evaluateServerFoodFit, ServerFoodFitSummary } from "./outputSafety";

export interface AuthoritativeServerContext {
  trustedSource: "supabase" | "client_fallback";
  profileForModel: Record<string, unknown>;
  diseasesForSafety: string[];
  contextForModel: Record<string, unknown>;
  productFacts: Record<string, any> | null;
  foodFit: ServerFoodFitSummary | null;
  recentHistoryFromServer?: string;
}

const BARCODE_PATTERN = /^\d{8,14}$/;

function cleanNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : null;
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}

function dayString(date: Date): string {
  return date.toISOString().split("T")[0];
}

function calculateServerTargets(profile: Record<string, any>): Record<string, number> {
  const age = cleanNumber(profile.age);
  const weight = cleanNumber(profile.weightKg);
  const height = cleanNumber(profile.heightCm);
  const customCal = cleanNumber(profile.customCaloriesGoal);
  const healthGoal = typeof profile.healthGoals === "string" ? profile.healthGoals.toLowerCase() : "";
  const activity = typeof profile.activityLevel === "string" ? profile.activityLevel.toLowerCase() : "moderate";
  const gender = typeof profile.gender === "string" ? profile.gender.toLowerCase() : "male";

  let calories: number | null = null;
  if (customCal !== null && customCal > 0) {
    calories = Math.round(customCal);
  } else if (age !== null && age >= 18 && weight !== null && height !== null) {
    const bmr = gender === "female"
      ? 10 * weight + 6.25 * height - 5 * age - 161
      : 10 * weight + 6.25 * height - 5 * age + 5;
    const multiplier =
      activity.includes("sedentary") ? 1.2
      : activity.includes("light") ? 1.375
      : activity.includes("very") || activity.includes("extra") ? 1.725
      : 1.55;
    let tdee = bmr * multiplier;
    if (healthGoal.includes("loss") || healthGoal.includes("lose")) tdee -= 400;
    else if (healthGoal.includes("muscle") || healthGoal.includes("gain")) tdee += 300;
    calories = Math.max(1200, Math.round(tdee));
  }

  const out: Record<string, number> = {};
  if (calories !== null) out.calories = calories;

  const customProtein = cleanNumber(profile.customProteinGoal);
  if (customProtein !== null && customProtein > 0) {
    out.protein = Math.round(customProtein);
  } else if (weight !== null) {
    const factor = healthGoal.includes("muscle") ? 1.8 : 1.2;
    out.protein = Math.round(weight * factor);
  }

  const customCarbs = cleanNumber(profile.customCarbsGoal);
  if (customCarbs !== null && customCarbs > 0) {
    out.carbs = Math.round(customCarbs);
  } else if (calories !== null) {
    out.carbs = Math.round((calories * 0.45) / 4);
  }

  const customFat = cleanNumber(profile.customFatGoal);
  if (customFat !== null && customFat > 0) {
    out.fat = Math.round(customFat);
  } else if (calories !== null) {
    out.fat = Math.round((calories * 0.30) / 9);
  }

  return out;
}

function aggregateTotals(logs: Record<string, any>[]): Record<string, number | null> {
  const fields: Array<[string, string]> = [
    ["calories", "calories"],
    ["protein", "protein"],
    ["carbs", "carbs"],
    ["fat", "fat"],
    ["sugar", "sugar"],
    ["sodium", "sodiumMg"],
  ];
  const out: Record<string, number | null> = { entriesLogged: logs.length };
  for (const [key, sourceKey] of fields) {
    if (logs.length === 0 || logs.some((row) => cleanNumber(row[sourceKey]) === null)) {
      out[key] = null;
    } else {
      out[key] = round(logs.reduce((acc, row) => acc + (cleanNumber(row[sourceKey]) ?? 0), 0));
    }
  }
  return out;
}

function buildContextFromServerRows(
  task: AiTask,
  rawProfile: Record<string, any>,
  rawDietRows: Record<string, any>[],
  rawScanRows: Record<string, any>[],
  rawActivity: Record<string, any> | null,
  now = new Date(),
): { profileForModel: Record<string, unknown>; contextForModel: Record<string, unknown>; diseases: string[] } {
  const profileForModel = profileData(rawProfile);
  const diseases = Array.isArray(rawProfile.diseases)
    ? rawProfile.diseases.map((item) => String(item ?? "").trim()).filter(Boolean).slice(0, 30)
    : [];

  if (task === "meal") {
    const mealProfile = Object.fromEntries(
      ["country", "region", "dietaryPreferences"]
        .filter((key) => profileForModel[key] !== undefined)
        .map((key) => [key, profileForModel[key]]),
    );
    return {
      profileForModel,
      contextForModel: nutritionContext("meal", { profile: mealProfile }),
      diseases,
    };
  }

  const todayKey = dayString(now);
  const validDates = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - i));
    return dayString(d);
  });

  const recentLogs = rawDietRows
    .filter((row) => typeof row.date === "string" && validDates.includes(row.date))
    .sort((a, b) => `${b.date ?? ""} ${b.time ?? ""}`.localeCompare(`${a.date ?? ""} ${a.time ?? ""}`));

  const targets = calculateServerTargets(rawProfile);
  const todayTotals = aggregateTotals(recentLogs.filter((r) => r.date === todayKey));
  const remaining: Record<string, number | null> = {};
  for (const [key, goal] of Object.entries(targets)) {
    const eaten = todayTotals[key];
    remaining[key] = typeof eaten === "number" ? round(goal - eaten) : null;
  }

  const dailyRows = validDates
    .map((d) => aggregateTotals(recentLogs.filter((r) => r.date === d)))
    .filter((summary) => (summary.entriesLogged ?? 0) > 0);

  const sevenDay: Record<string, unknown> = {
    daysLogged: dailyRows.length,
  };
  for (const nutrient of ["calories", "protein", "carbs", "fat", "sugar", "sodium"]) {
    const cap = nutrient[0].toUpperCase() + nutrient.slice(1);
    sevenDay[`average${cap}`] =
      dailyRows.length === 0 || dailyRows.some((r) => r[nutrient] === null)
        ? null
        : round(dailyRows.reduce((sum, r) => sum + (Number(r[nutrient]) || 0), 0) / dailyRows.length);
  }

  const rawContext: Record<string, unknown> = {
    profile: profileForModel,
    targets,
    today: { ...todayTotals, remaining },
  };
  if (task === "chat" || task === "macros") {
    rawContext.sevenDay = sevenDay;
    if (rawActivity && ["healthConnect", "pedometerEstimate"].includes(String(rawActivity.source ?? ""))) {
      rawContext.activity = {
        source: rawActivity.source,
        ...(cleanNumber(rawActivity.steps) !== null ? { steps: cleanNumber(rawActivity.steps) } : {}),
        ...(cleanNumber(rawActivity.activeCalories) !== null ? { activeCalories: cleanNumber(rawActivity.activeCalories) } : {}),
      };
    }
  }
  if (task === "chat" || task === "plan") {
    rawContext.recentMeals = recentLogs.slice(0, 8).map((row) => ({
      ...(typeof row.name === "string" ? { name: boundedString(row.name, 160, true) } : {}),
      ...(cleanNumber(row.calories) !== null ? { calories: cleanNumber(row.calories) } : {}),
      ...(cleanNumber(row.protein) !== null ? { protein: cleanNumber(row.protein) } : {}),
      ...(cleanNumber(row.carbs) !== null ? { carbs: cleanNumber(row.carbs) } : {}),
      ...(cleanNumber(row.fat) !== null ? { fat: cleanNumber(row.fat) } : {}),
      ...(cleanNumber(row.sugar) !== null ? { sugar: cleanNumber(row.sugar) } : {}),
      ...(cleanNumber(row.sodiumMg) !== null ? { sodium: cleanNumber(row.sodiumMg) } : {}),
    }));
  }
  if (task === "chat") {
    rawContext.recentScans = rawScanRows.slice(0, 5);
  }

  return {
    profileForModel,
    contextForModel: nutritionContext(task, rawContext),
    diseases,
  };
}

async function querySupabaseRest(
  baseUrl: string,
  serviceKey: string,
  path: string,
  fetcher: typeof fetch,
): Promise<any[]> {
  const response = await fetcher(`${baseUrl}/rest/v1/${path}`, {
    method: "GET",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      Accept: "application/json",
    },
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error(`Supabase query failed: ${response.status}`);
  const parsed = await response.json();
  return Array.isArray(parsed) ? parsed : [];
}

function extractRequestedBarcode(task: AiTask, content: string, clientData: Record<string, any>): string | null {
  const direct = typeof clientData?.barcode === "string" ? clientData.barcode.trim() : "";
  if (BARCODE_PATTERN.test(direct)) return direct;
  if (task === "analysis" || task === "chat") {
    try {
      const parsed = JSON.parse(content);
      const nested =
        parsed?.barcode ??
        parsed?.product?.barcode ??
        parsed?.currentProduct?.barcode;
      if (typeof nested === "string" && BARCODE_PATTERN.test(nested.trim())) {
        return nested.trim();
      }
    } catch {
      // Plain text content
    }
  }
  return null;
}

function extractClientProductFallback(task: AiTask, content: string): Record<string, any> | null {
  if (task !== "analysis" && task !== "chat") return null;
  try {
    const parsed = JSON.parse(content);
    const candidate = task === "analysis" ? parsed?.product : parsed?.currentProduct;
    if (candidate && typeof candidate === "object" && !Array.isArray(candidate)) {
      return candidate as Record<string, any>;
    }
  } catch {
    // Plain text content
  }
  return null;
}

export interface ServerContextDeps {
  supabaseUrl?: string;
  supabaseServiceKey?: string;
  fetcher?: typeof fetch;
  loadCanonicalProduct?: (barcode: string) => Promise<Record<string, any> | null>;
  now?: Date;
}

async function defaultLoadProduct(barcode: string): Promise<Record<string, any> | null> {
  try {
    const snap = await getFirestore().doc(`products/${barcode}`).get();
    const data = snap.data();
    if (data && data.schemaVersion === 2 && data.nutrition?.sodiumMgPer100g !== undefined) {
      return data as Record<string, any>;
    }
  } catch {
    // Firestore might not be initialized in isolated unit tests.
  }
  return null;
}

/**
 * Zero-trust context builder: when Supabase service credentials are present,
 * fetches profile, diet logs, scans, activity, and recent chat history from DB
 * using authenticated `uid`, and fetches canonical product docs by `barcode` to
 * recompute FoodFit server-side instead of trusting client claims.
 */
export async function resolveServerContext(
  uid: string,
  task: AiTask,
  content: string,
  clientData: Record<string, any>,
  deps: ServerContextDeps = {},
): Promise<AuthoritativeServerContext> {
  const serviceKey = deps.supabaseServiceKey?.trim();
  const baseUrl = (deps.supabaseUrl || "https://tslcgavpkujkfexzmisk.supabase.co").replace(/\/+$/, "");
  const fetcher = deps.fetcher ?? fetch;
  const now = deps.now ?? new Date();
  const loadProduct = deps.loadCanonicalProduct ?? defaultLoadProduct;

  const clientProfileRaw = (clientData?.profile && typeof clientData.profile === "object" && !Array.isArray(clientData.profile))
    ? (clientData.profile as Record<string, any>)
    : {};
  const fallbackProfile = profileData(clientProfileRaw);
  const fallbackContext = nutritionContext(task, clientData?.context);

  let serverProfileRaw: Record<string, any> | null = null;
  let serverDietRows: Record<string, any>[] = [];
  let serverScanRows: Record<string, any>[] = [];
  let serverActivity: Record<string, any> | null = null;
  let serverChatHistory: string | undefined;
  let trustedSource: "supabase" | "client_fallback" = "client_fallback";

  if (serviceKey) {
    const encodedUid = encodeURIComponent(uid);
    const todayKey = encodeURIComponent(dayString(now));
    try {
      const profilePromise = querySupabaseRest(
        baseUrl,
        serviceKey,
        `profiles?user_id=eq.${encodedUid}&id=eq.profile&deleted=eq.false&select=data&limit=1`,
        fetcher,
      );
      const dietPromise = task === "meal"
        ? Promise.resolve([])
        : querySupabaseRest(
            baseUrl,
            serviceKey,
            `diet_entries?user_id=eq.${encodedUid}&deleted=eq.false&select=data&order=updated_at.desc&limit=120`,
            fetcher,
          );
      const scansPromise = task === "chat"
        ? querySupabaseRest(
            baseUrl,
            serviceKey,
            `scans?user_id=eq.${encodedUid}&deleted=eq.false&select=data&order=updated_at.desc&limit=10`,
            fetcher,
          )
        : Promise.resolve([]);
      const activityPromise = (task === "chat" || task === "macros")
        ? querySupabaseRest(
            baseUrl,
            serviceKey,
            `activity_logs?user_id=eq.${encodedUid}&id=eq.${todayKey}&deleted=eq.false&select=data&limit=1`,
            fetcher,
          )
        : Promise.resolve([]);
      const chatPromise = task === "chat"
        ? querySupabaseRest(
            baseUrl,
            serviceKey,
            `chat_messages?user_id=eq.${encodedUid}&deleted=eq.false&select=data&order=updated_at.desc&limit=12`,
            fetcher,
          )
        : Promise.resolve([]);

      const [profileRows, dietRows, scanRows, activityRows, chatRows] = await Promise.all([
        profilePromise,
        dietPromise,
        scansPromise,
        activityPromise,
        chatPromise,
      ]);

      const rawProf = profileRows[0]?.data;
      if (rawProf && typeof rawProf === "object" && !Array.isArray(rawProf)) {
        serverProfileRaw = rawProf as Record<string, any>;
        trustedSource = "supabase";
      }
      serverDietRows = dietRows.map((r) => r?.data).filter((d) => d && typeof d === "object");
      serverScanRows = scanRows.map((r) => r?.data).filter((d) => d && typeof d === "object");
      const rawAct = activityRows[0]?.data;
      if (rawAct && typeof rawAct === "object") {
        serverActivity = rawAct as Record<string, any>;
      }
      if (chatRows.length > 0) {
        const lines = chatRows
          .map((r) => r?.data)
          .filter((d) => d && typeof d === "object" && d.isGreeting !== true && d.isError !== true)
          .reverse()
          .map((d) => `${d.isUser ? "User" : "Assistant"}: ${String(d.message ?? "").slice(0, 600)}`)
          .filter(Boolean);
        if (lines.length > 0) {
          serverChatHistory = lines.join("\n").slice(-7000);
        }
      }
    } catch {
      // Fall back to sanitized client context only if DB lookup fails temporarily.
    }
  }

  let built: { profileForModel: Record<string, unknown>; contextForModel: Record<string, unknown>; diseases: string[] };
  if (serverProfileRaw !== null) {
    built = buildContextFromServerRows(
      task,
      serverProfileRaw,
      serverDietRows,
      serverScanRows,
      serverActivity,
      now,
    );
  } else {
    built = {
      profileForModel: fallbackProfile,
      contextForModel: fallbackContext,
      diseases: [],
    };
  }

  // Resolve product context deterministically: prefer Firestore canonical `products/{barcode}` by barcode,
  // and ALWAYS recompute FoodFit server-side instead of accepting caller-asserted scores/conflicts.
  let productFacts: Record<string, any> | null = null;
  let foodFit: ServerFoodFitSummary | null = null;
  const barcode = extractRequestedBarcode(task, content, clientData);
  if (barcode) {
    productFacts = await loadProduct(barcode);
  }
  if (!productFacts) {
    productFacts = extractClientProductFallback(task, content);
  }
  if (productFacts) {
    const fitProfile = {
      allergies: built.profileForModel.allergies,
      dietaryPreferences: built.profileForModel.dietaryPreferences,
      healthGoals: built.profileForModel.healthGoals,
      diseases: built.diseases,
    };
    foodFit = evaluateServerFoodFit(
      productFacts,
      fitProfile,
      (built.contextForModel.today as Record<string, any>) ?? undefined,
      (built.contextForModel.targets as Record<string, any>) ?? undefined,
    );
  }

  return {
    trustedSource,
    profileForModel: built.profileForModel,
    diseasesForSafety: built.diseases,
    contextForModel: built.contextForModel,
    productFacts,
    foodFit,
    recentHistoryFromServer: serverChatHistory,
  };
}
