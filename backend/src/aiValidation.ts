export type AiTask = "meal" | "plan" | "chat" | "macros" | "analysis" | "quickReplies";
export const limits: Record<AiTask, number> = { meal: 15, plan: 2, chat: 20, macros: 2, analysis: 15, quickReplies: 20 };

export function requiresEmailVerification(
  token: { email_verified?: unknown; firebase?: { sign_in_provider?: unknown } } | undefined,
): boolean {
  return token?.firebase?.sign_in_provider === "password" && token.email_verified !== true;
}

export function boundedNumber(value: unknown, name: string, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > max) {
    throw new Error(`Invalid ${name}`);
  }
  return value;
}
export function boundedString(value: unknown, max: number, optional = false): string {
  if (optional && (value === undefined || value === null)) return "";
  if (typeof value !== "string" || (!optional && !value.trim()) || value.length > max) throw new Error("Invalid text");
  return value.trim();
}
export function profileData(value: unknown): Record<string, unknown> {
  if (value === undefined || value === null) return {};
  if (typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid profile");
  const input = value as Record<string, unknown>;
  const output: Record<string, unknown> = {};
  for (const key of ["country", "region", "healthGoals", "activityLevel", "gender"]) {
    if (input[key] !== undefined) output[key] = boundedString(input[key], 120, true);
  }
  for (const key of ["allergies", "dietaryPreferences"]) {
    if (input[key] === undefined) continue;
    if (!Array.isArray(input[key]) || (input[key] as unknown[]).length > 30) throw new Error("Invalid preferences");
    output[key] = (input[key] as unknown[]).map((item) => boundedString(item, 80));
  }
  for (const key of ["age", "weightKg", "heightCm", "customCaloriesGoal", "customProteinGoal", "customCarbsGoal", "customFatGoal"]) {
    if (input[key] !== undefined) output[key] = boundedNumber(input[key], key, key.startsWith("custom") ? 10000 : 400);
  }
  return output;
}

function meal(value: any): Record<string, any> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid meal");
  return {
    name: boundedString(value.name, 160),
    calories: boundedNumber(value.calories, "calories", 5000),
    protein: boundedNumber(value.protein, "protein", 500),
    carbs: boundedNumber(value.carbs, "carbs", 1000),
    sugar: boundedNumber(value.sugar, "sugar", 500),
    fat: boundedNumber(value.fat, "fat", 500),
    portionDescription: boundedString(value.portionDescription, 400, true),
  };
}

/** Allowlist output fields; reject incomplete and pathological model responses. */
export function validateOutput(task: AiTask, value: any): Record<string, any> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid response");
  if (task === "meal") return meal(value);
  if (task === "chat") return { reply: boundedString(value.reply, 10000), mealData: value.mealData == null ? null : meal(value.mealData) };
  if (task === "analysis") return { summary: boundedString(value.summary, 2500) };
  if (task === "quickReplies") {
    if (!Array.isArray(value.replies) || value.replies.length < 2 || value.replies.length > 4) throw new Error('Invalid replies');
    const replies = value.replies.map((r: unknown) => boundedString(r, 100));
    if (new Set(replies.map((r: string) => r.toLowerCase())).size !== replies.length ||
      replies.some((r: string) => /\b(cure|diagnos|treat disease|stop medication|guaranteed safe)/i.test(r))) throw new Error('Invalid replies');
    return { replies };
  }
  if (task === "macros") {
    const calories = boundedNumber(value.calories, "calories", 5000);
    if (calories < 1200) throw new Error("Target needs professional review");
    return { calories, protein: boundedNumber(value.protein, "protein", 400),
      carbs: boundedNumber(value.carbs, "carbs", 800), fat: boundedNumber(value.fat, "fat", 300),
      explanation: boundedString(value.explanation, 2500) };
  }
  if (!Array.isArray(value.meals) || value.meals.length !== 4) throw new Error("Invalid meal plan");
  const types = ["Breakfast", "Lunch", "Dinner", "Snack"];
  const meals = value.meals.map((item: any) => ({ ...meal(item),
    type: boundedString(item.type, 20), description: boundedString(item.description, 800),
    ingredients: Array.isArray(item.ingredients) && item.ingredients.length > 0 && item.ingredients.length <= 40
      ? item.ingredients.map((ingredient: unknown) => boundedString(ingredient, 100))
      : (() => { throw new Error("Meal ingredients missing"); })(),
  }));
  if (new Set(meals.map((item: any) => item.type)).size !== 4 || meals.some((item: any) => !types.includes(item.type))) {
    throw new Error("Incomplete plan");
  }
  return { summary: boundedString(value.summary, 2500), meals,
    totalCalories: meals.reduce((sum: number, item: any) => sum + item.calories, 0),
    totalProtein: meals.reduce((sum: number, item: any) => sum + item.protein, 0) };
}
