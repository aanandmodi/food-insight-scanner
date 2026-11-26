import { AiTask } from "./aiValidation";

export type ServerAllergenStatus =
  | "confirmedConflict"
  | "possibleTrace"
  | "noDetectedConflict"
  | "insufficientData";

export interface ServerAllergenResult {
  status: ServerAllergenStatus;
  confirmed: string[];
  traces: string[];
}

export interface ServerFoodFitSummary {
  score: number | null;
  scoreStatus:
    | "withheld_due_to_allergen_conflict"
    | "withheld_due_to_dietary_restriction"
    | "insufficient_data"
    | "available";
  confidence: "high" | "medium" | "low" | "insufficientData";
  positives: string[];
  cautions: string[];
  conflicts: string[];
  unknowns: string[];
  hasCriticalAllergenConflict: boolean;
}

export interface OutputSafetyEvaluation {
  blocked: boolean;
  reason?: string;
  ruleId?: string;
  value: Record<string, any>;
  safetyFlags: string[];
}

const ALLERGEN_GROUPS: Record<string, string[]> = {
  milk: ["milk", "dairy", "whey", "casein", "lactose", "cheese", "butter", "cream", "curd", "yogurt", "dahi", "paneer", "ghee", "makkhan", "khoya", "mawa"],
  peanut: ["peanut", "peanuts", "groundnut", "groundnuts", "moongfali", "singdana"],
  "tree nuts": ["tree nuts", "nuts", "almond", "almonds", "badam", "cashew", "cashews", "kaju", "walnut", "walnuts", "akhrot", "pistachio", "pistachios", "pista", "hazelnut", "hazelnuts", "pecan", "pecans"],
  gluten: ["gluten", "wheat", "maida", "atta", "suji", "sooji", "rava", "semolina", "barley", "rye", "malt"],
  soy: ["soy", "soya", "soybean", "soybeans", "tofu"],
  egg: ["egg", "eggs", "albumin", "anda"],
  fish: ["fish", "salmon", "tuna", "anchovy", "anchovies", "machli"],
  shellfish: ["shellfish", "shrimp", "prawn", "prawns", "jhinga", "crab", "lobster"],
  sesame: ["sesame", "tahini", "til"],
};

const TRACE_MARKER = /may contain|traces of|made in a facility/i;
const GLUTEN_REGEX = /\b(gluten|wheat|maida|atta|suji|sooji|rava|semolina|barley|rye|malt|triticale|spelt|kamut|seitan)\b/i;
const LACTOSE_REGEX = /\b(milk|lactose|whey|casein|caseinate|cream|butter|ghee|cheese|paneer|curd|yogurt|yoghurt|buttermilk|skimmed milk|milk solids|milk powder)\b/i;
const ADDED_SUGAR_REGEX = /\b(sugar|sucrose|glucose|fructose|high fructose|corn syrup|hfcs|maltose|dextrose|invert sugar|maltodextrin|jaggery|honey|molasses|cane syrup)\b/i;
const RENAL_PHOS_K_REGEX = /\b(phosphoric acid|sodium phosphate|monosodium phosphate|disodium phosphate|trisodium phosphate|pyrophosphate|triphosphate|polyphosphate|potassium chloride)\b/i;
const RENAL_INS_REGEX = /\b(?:INS\s*|E)(?:338|339|340|341|343|450|451|452|508)[a-z]?\b/i;
const NEGATION_CONTEXT_REGEX = /\b(avoid|skip|without|free|allerg(?:y|ies|ic)|intoleran\w*|conflict\w*|warning|caution|unsafe|danger|exclude|not\s+(?:suitable|recommended|safe)|do\s+not\s+eat|steer\s+clear|instead\s+of|replace)\b/i;

// Non-dairy culinary substitutes that share dairy nouns ("Soy Milk", "Peanut Butter", "Soy Paneer")
// must not trigger false-positive dairy conflicts, while retaining nut/soy detection on their first word.
const NON_DAIRY_COMPOUND_REGEX =
  /\b(?:(?:soy|soya|tofu|oat|oats|rice|almond|cashew|hazelnut|walnut|pistachio|coconut|hemp|pea|flax|plant(?:[\s\u00A0\-\u2010-\u2014]*based)?|vegan|non[\s\u00A0\-\u2010-\u2014]*dairy|dairy[\s\u00A0\-\u2010-\u2014]*free)[\s\u00A0\-\u2010-\u2014]+(?:milk|mylk|paneer|curd|yogurt|yoghurt|butter|cheese|cream|ghee)|(?:peanut|almond|cashew|hazelnut|walnut|pistachio|sunflower|pumpkin(?:[\s\u00A0\-\u2010-\u2014]+seed)?|sesame|seed|nut|cocoa|shea|apple)[\s\u00A0\-\u2010-\u2014]+butter|tofu[\s\u00A0]*\([\s\u00A0]*soy[\s\u00A0\-\u2010-\u2014]+paneer[\s\u00A0]*\)|coconut[\s\u00A0\-\u2010-\u2014]+cream|cream[\s\u00A0]+of[\s\u00A0]+tartar|(?:dairy|milk)[\s\u00A0\-\u2010-\u2014]*free)\b/gi;

function stripNonDairyCompounds(text: string): string {
  return text.replace(NON_DAIRY_COMPOUND_REGEX, (match) => {
    const first = match.trim().split(/[\s(]+/)[0]?.toLowerCase() ?? "";
    if (["soy", "soya", "oat", "rice", "almond", "cashew", "hazelnut", "walnut", "pistachio", "peanut", "sesame", "coconut", "hemp", "pea", "flax", "tofu"].includes(first)) {
      return `${first} [plant-substitute]`;
    }
    return "[plant-substitute]";
  });
}

function isDairyAllergy(allergy: string): boolean {
  const lower = allergy.toLowerCase().trim();
  return ALLERGEN_GROUPS.milk.includes(lower);
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function containsTerm(text: string, term: string): boolean {
  if (!text || !term) return false;
  const escaped = escapeRegex(term);
  return new RegExp(`(^|[^a-z])${escaped}([^a-z]|$)`, "i").test(text);
}

function allergenTerms(allergy: string): string[] {
  const lower = allergy.toLowerCase().trim();
  if (!lower) return [];
  if (lower === "nuts") {
    return [...ALLERGEN_GROUPS["tree nuts"], ...ALLERGEN_GROUPS.peanut];
  }
  for (const [key, terms] of Object.entries(ALLERGEN_GROUPS)) {
    if (key === lower || terms.includes(lower)) return terms;
  }
  return [lower];
}

function joinTagList(value: unknown): string {
  if (!Array.isArray(value)) return "";
  return value
    .map((item) => String(item ?? "").split(":").pop()?.replace(/-/g, " ").trim() ?? "")
    .filter(Boolean)
    .join(" ");
}

/** Deterministic backend mirror of Flutter AllergenSafetyService.evaluate. */
export function evaluateAllergensServer(
  product: Record<string, any>,
  userAllergies: string[],
): ServerAllergenResult {
  const declared = joinTagList(product.allergens);
  const rawIngredients = [
    typeof product.ingredientsText === "string" ? product.ingredientsText : "",
    joinTagList(product.ingredients),
  ].join(" ");
  const traceMatch = TRACE_MARKER.exec(rawIngredients);
  const ingredients = traceMatch ? rawIngredients.slice(0, traceMatch.index) : rawIngredients;
  const traces = `${joinTagList(product.traces)} ${traceMatch ? rawIngredients.slice(traceMatch.index) : ""}`.trim();
  const hasEvidence = Boolean(declared || traces || ingredients.trim());
  const confirmed: string[] = [];
  const possible: string[] = [];

  for (const rawAllergy of userAllergies) {
    const allergy = rawAllergy.trim();
    if (!allergy) continue;
    const terms = allergenTerms(allergy);
    const dairyCheck = isDairyAllergy(allergy);
    const ingTarget = dairyCheck ? stripNonDairyCompounds(ingredients) : ingredients;
    const traceTarget = dairyCheck ? stripNonDairyCompounds(traces) : traces;
    if (terms.some((t) => containsTerm(declared, t) || containsTerm(ingTarget, t))) {
      confirmed.push(allergy);
    } else if (terms.some((t) => containsTerm(traceTarget, t))) {
      possible.push(allergy);
    }
  }

  if (confirmed.length > 0) {
    return { status: "confirmedConflict", confirmed, traces: possible };
  }
  if (possible.length > 0) {
    return { status: "possibleTrace", confirmed, traces: possible };
  }
  if (!hasEvidence) {
    return { status: "insufficientData", confirmed: [], traces: [] };
  }
  return { status: "noDetectedConflict", confirmed: [], traces: [] };
}

function evaluateDietaryConflict(
  product: Record<string, any>,
  preferences: string[],
): string | null {
  const diet = preferences.join(" ").toLowerCase().replace(/-/g, " ");
  if (!diet.trim()) return null;
  const combined = `${product.name ?? ""} ${product.ingredientsText ?? ""} ${joinTagList(product.ingredients)}`.toLowerCase();
  const tags = joinTagList(product.ingredientsAnalysisTags).toLowerCase();
  const wantsVegan = diet.includes("vegan") && !diet.includes("non vegan");
  const wantsVeg = diet.includes("vegetarian") && !diet.includes("non vegetarian");

  const dairyStripped = stripNonDairyCompounds(combined);
  if (wantsVegan && (tags.includes("non vegan") || /\b(milk|whey|casein|egg|honey|cheese|butter|ghee|paneer|curd|yogurt|fish|meat|chicken|prawn|mutton)\b/i.test(dairyStripped))) {
    return "Ingredients may not fit a vegan diet";
  }
  if (wantsVeg && (tags.includes("non vegetarian") || /\b(fish|meat|chicken|beef|pork|mutton|gelatin|prawn|shrimp)\b/i.test(combined))) {
    return "Ingredients may not fit a vegetarian diet";
  }
  return null;
}

function evaluateConditionConflictsServer(
  product: Record<string, any>,
  conditions: string[],
  nutrition: { sugar?: number | null; sodium?: number | null } = {},
): { conflicts: string[]; cautions: string[]; hasCritical: boolean } {
  const conflicts: string[] = [];
  const cautions: string[] = [];
  let hasCritical = false;

  const combined = `${joinTagList(product.allergens)} ${product.ingredientsText ?? ""} ${joinTagList(product.ingredients)} ${joinTagList(product.additives)}`.trim();
  const active = conditions.map((c) => c.trim().toLowerCase()).filter((c) => c && c !== "none");

  for (const cond of active) {
    if (cond.includes("celiac") && (GLUTEN_REGEX.test(combined) || /\bglutens?\b/i.test(combined))) {
      conflicts.push("Contains gluten-related ingredients");
      hasCritical = true;
    }
    if ((cond.includes("lactose") || cond.includes("dairy")) && !/lactose[\s-]?free/i.test(combined) && LACTOSE_REGEX.test(stripNonDairyCompounds(combined))) {
      conflicts.push("Contains milk or lactose ingredients");
    }
    if (cond.includes("diabet")) {
      if ((nutrition.sugar ?? -1) > 15) {
        conflicts.push("High sugar for diabetes management");
      } else if ((nutrition.sugar ?? -1) > 5 || ADDED_SUGAR_REGEX.test(combined)) {
        cautions.push("Contains added sugar or moderate sugar");
      }
    }
    if ((cond.includes("hypertens") || cond.includes("blood pressure") || cond.includes("bp")) && (nutrition.sodium ?? -1) >= 500) {
      conflicts.push("High sodium content");
    }
    if ((cond.includes("kidney") || cond.includes("renal")) && (RENAL_PHOS_K_REGEX.test(combined) || RENAL_INS_REGEX.test(combined) || (nutrition.sodium ?? -1) >= 400)) {
      conflicts.push("Contains renal-restricted sodium, phosphate, or potassium additive");
    }
  }
  return { conflicts, cautions, hasCritical };
}

function validNum(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : null;
}

/** Deterministic zero-trust FoodFit evaluation computed strictly on the server. */
export function evaluateServerFoodFit(
  product: Record<string, any>,
  profile: {
    allergies?: unknown;
    dietaryPreferences?: unknown;
    healthGoals?: unknown;
    diseases?: unknown;
  },
  todayTotals?: Record<string, any>,
  targets?: Record<string, any>,
): ServerFoodFitSummary {
  const allergies = Array.isArray(profile.allergies) ? profile.allergies.map(String) : [];
  const preferences = Array.isArray(profile.dietaryPreferences) ? profile.dietaryPreferences.map(String) : [];
  const conditions = Array.isArray(profile.diseases) ? profile.diseases.map(String) : [];
  const healthGoal = typeof profile.healthGoals === "string" ? profile.healthGoals : "";

  const allergen = evaluateAllergensServer(product, allergies);
  const nutrition = (product.nutrition && typeof product.nutrition === "object" ? product.nutrition : {}) as Record<string, unknown>;
  const val = (canonical: string, legacy: string) => validNum(nutrition[canonical] ?? nutrition[legacy]);

  const calories = val("energyKcalPer100g", "calories");
  const sugar = val("sugarGPer100g", "sugar");
  const protein = val("proteinGPer100g", "protein");
  const fiber = val("fiberGPer100g", "fiber");
  const sodium = validNum(nutrition.sodiumMgPer100g ?? (product.schemaVersion === 2 ? nutrition.sodium : null));

  const positives: string[] = [];
  const cautions: string[] = [];
  const conflicts: string[] = [];
  const unknowns: string[] = [];

  if (allergen.confirmed.length > 0) {
    conflicts.push(`Contains ${allergen.confirmed.join(", ")}`);
  }
  if (allergen.traces.length > 0) {
    cautions.push(`May contain traces of ${allergen.traces.join(", ")}`);
  }
  if (allergen.status === "insufficientData") {
    unknowns.push("Allergen information is missing");
  }
  if (sodium === null) unknowns.push("Sodium amount is unknown");
  if (sugar === null) unknowns.push("Sugar amount is unknown");
  if (protein === null) unknowns.push("Protein amount is unknown");

  let score = 70;
  const grade = typeof product.nutriscore === "string" ? product.nutriscore.toLowerCase() : "";
  score += ({ a: 8, b: 4, c: 0, d: -4, e: -8 } as Record<string, number>)[grade] ?? 0;

  if (sodium !== null && sodium >= 600) {
    score -= 15;
    cautions.push(`High sodium (${Math.round(sodium)} mg per 100g)`);
  }
  if (sugar !== null && sugar > 15) {
    score -= 12;
    cautions.push(`High sugar (${sugar.toFixed(1)} g per 100g)`);
  }
  if (protein !== null && protein >= 10) {
    score += 9;
    positives.push(`Good protein (${protein.toFixed(1)} g per 100g)`);
  }
  if (fiber !== null && fiber >= 6) {
    score += 8;
    positives.push(`Good fiber (${fiber.toFixed(1)} g per 100g)`);
  }
  if (calories !== null && calories >= 400) {
    score -= 8;
    cautions.push(`Energy dense (${Math.round(calories)} kcal per 100g)`);
  }
  if (product.novaGroup === 4) {
    score -= 8;
    cautions.push("Ultra processed (NOVA 4)");
  }

  const dietConflict = evaluateDietaryConflict(product, preferences);
  if (dietConflict) conflicts.push(dietConflict);

  const condResult = evaluateConditionConflictsServer(product, conditions, { sugar, sodium });
  if (condResult.conflicts.length > 0) {
    conflicts.push(...condResult.conflicts);
  }
  if (condResult.cautions.length > 0) {
    cautions.push(...condResult.cautions);
  }

  if (healthGoal.toLowerCase().includes("muscle") && protein !== null && protein >= 10) {
    score += 4;
    positives.push("Protein supports your stated goal");
  }
  if (todayTotals && targets && calories !== null && typeof targets.calories === "number" && typeof todayTotals.calories === "number") {
    const remainingCalories = targets.calories - todayTotals.calories;
    if (calories > remainingCalories) {
      cautions.push("100g provides more energy than your remaining logged calorie target; check your portion");
    }
  }

  if (conflicts.length > 0) score = Math.min(25, Math.max(0, score));
  if (allergen.traces.length > 0) score = Math.min(45, Math.max(0, score));

  const knownCount = [calories, sugar, protein, fiber, sodium].filter((v) => v !== null).length;
  const confidence: ServerFoodFitSummary["confidence"] =
    knownCount < 3
      ? "insufficientData"
      : knownCount === 5 && allergen.status !== "insufficientData" && Array.isArray(product.allergens) && product.allergens.length > 0
      ? "high"
      : knownCount >= 4
      ? "medium"
      : "low";

  const criticalAllergen = allergen.status === "confirmedConflict";
  const criticalCondition = condResult.hasCritical;
  const finalScore = criticalAllergen || criticalCondition || confidence === "insufficientData"
    ? null
    : Math.min(100, Math.max(0, Math.round(score)));

  return {
    score: finalScore,
    scoreStatus: criticalAllergen
      ? "withheld_due_to_allergen_conflict"
      : criticalCondition
      ? "withheld_due_to_dietary_restriction"
      : finalScore === null
      ? "insufficient_data"
      : "available",
    confidence,
    positives,
    cautions,
    conflicts,
    unknowns,
    hasCriticalAllergenConflict: criticalAllergen,
  };
}

/**
 * Layer 4: Deterministic safety cross-check on validated model outputs.
 * Protects plan meals, chat mealData suggestions, chat text recommendations, and analysis summaries.
 */
export function enforceOutputSafety(
  task: AiTask,
  validated: Record<string, any>,
  profile: {
    allergies?: unknown;
    dietaryPreferences?: unknown;
    diseases?: unknown;
  },
  serverFoodFit?: ServerFoodFitSummary,
): OutputSafetyEvaluation {
  const allergies = Array.isArray(profile.allergies) ? profile.allergies.map(String).filter(Boolean) : [];
  const preferences = Array.isArray(profile.dietaryPreferences) ? profile.dietaryPreferences.map(String).filter(Boolean) : [];
  const conditions = Array.isArray(profile.diseases) ? profile.diseases.map(String).filter(Boolean) : [];
  const safetyFlags: string[] = [];

  if (task === "plan") {
    const meals = Array.isArray(validated.meals) ? validated.meals : [];
    for (const meal of meals) {
      const mealProduct = {
        name: meal.name,
        ingredients: meal.ingredients,
        ingredientsText: `${meal.name} ${meal.description} ${meal.portionDescription ?? ""}`,
      };
      const allergenResult = evaluateAllergensServer(mealProduct, allergies);
      if (allergenResult.status === "confirmedConflict" || allergenResult.status === "possibleTrace") {
        return {
          blocked: true,
          reason: `Generated meal "${meal.name}" conflicted with a saved allergy (${allergenResult.confirmed.concat(allergenResult.traces).join(", ")}). Please retry.`,
          ruleId: "plan-allergen-conflict",
          value: validated,
          safetyFlags: ["plan_allergen_conflict"],
        };
      }
      const dietConflict = evaluateDietaryConflict(mealProduct, preferences);
      if (dietConflict) {
        return {
          blocked: true,
          reason: `Generated meal "${meal.name}" conflicted with your dietary preference (${dietConflict}). Please retry.`,
          ruleId: "plan-diet-conflict",
          value: validated,
          safetyFlags: ["plan_diet_conflict"],
        };
      }
      const condResult = evaluateConditionConflictsServer(mealProduct, conditions);
      if (condResult.hasCritical || condResult.conflicts.length > 0) {
        return {
          blocked: true,
          reason: `Generated meal "${meal.name}" may conflict with your saved dietary/condition constraints. Please retry.`,
          ruleId: "plan-condition-conflict",
          value: validated,
          safetyFlags: ["plan_condition_conflict"],
        };
      }
    }
    return { blocked: false, value: validated, safetyFlags };
  }

  if (task === "chat") {
    const updated = { ...validated };
    const warnings: string[] = [];

    if (updated.mealData && typeof updated.mealData === "object") {
      const mealProduct = {
        name: updated.mealData.name,
        ingredientsText: `${updated.mealData.name} ${updated.mealData.portionDescription ?? ""}`,
      };
      const mealAllergens = evaluateAllergensServer(mealProduct, allergies);
      if (mealAllergens.status === "confirmedConflict" || mealAllergens.status === "possibleTrace") {
        const hit = mealAllergens.confirmed.concat(mealAllergens.traces).join(", ");
        updated.mealData = null;
        safetyFlags.push("chat_meal_data_allergen_removed");
        warnings.push(`Meal logging card withheld: "${validated.mealData.name}" may involve a saved allergy (${hit}).`);
      } else {
        const condResult = evaluateConditionConflictsServer(mealProduct, conditions);
        if (condResult.hasCritical) {
          updated.mealData = null;
          safetyFlags.push("chat_meal_data_condition_removed");
          warnings.push("Meal logging card withheld due to a critical dietary/condition ingredient check.");
        }
      }
    }

    if (typeof updated.reply === "string" && allergies.length > 0) {
      const clauses = updated.reply.split(/[\n.!?;]+/);
      const unqualifiedAllergens = new Set<string>();
      for (const allergy of allergies) {
        const terms = allergenTerms(allergy);
        const dairyCheck = isDairyAllergy(allergy);
        for (const clause of clauses) {
          const trimmed = clause.trim();
          if (!trimmed) continue;
          const clauseTarget = dairyCheck ? stripNonDairyCompounds(trimmed) : trimmed;
          const mentionsTerm = terms.some((term) => containsTerm(clauseTarget, term));
          if (mentionsTerm && !NEGATION_CONTEXT_REGEX.test(trimmed)) {
            unqualifiedAllergens.add(allergy);
          }
        }
      }
      if (unqualifiedAllergens.size > 0) {
        safetyFlags.push("chat_reply_allergen_advisory");
        warnings.push(
          `Allergy safety check: Your profile lists allergies (${Array.from(unqualifiedAllergens).join(", ")}). Double-check exact ingredients and cross-contamination before eating any mentioned foods.`,
        );
      }
    }

    if (warnings.length > 0 && typeof updated.reply === "string") {
      updated.reply = `${updated.reply.trim()}\n\n${warnings.join("\n")}`.slice(0, 10000);
    }
    return { blocked: false, value: updated, safetyFlags };
  }

  if (task === "analysis" && serverFoodFit?.hasCriticalAllergenConflict && typeof validated.summary === "string") {
    const claimsSafe = /\b(?:safe\s+to\s+eat|no\s+allergen\s+conflict|completely\s+safe)\b/i.test(validated.summary);
    const inventsScore = /\b(?:score\s+(?:is|of)\s*\d+|rated\s+\d+\s*\/\s*100)\b/i.test(validated.summary);
    if (claimsSafe || inventsScore) {
      safetyFlags.push("analysis_critical_override");
      return {
        blocked: false,
        value: {
          ...validated,
          summary:
            `Critical allergen conflict detected (${serverFoodFit.conflicts.join("; ") || "check product allergens"}). Numeric score is withheld due to allergen conflict. Do not consume without verifying safe label status.`,
        },
        safetyFlags,
      };
    }
  }

  return { blocked: false, value: validated, safetyFlags };
}
