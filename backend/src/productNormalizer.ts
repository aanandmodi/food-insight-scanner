export interface ProductFacts {
  barcode: string;
  name: string;
  brand: string;
  category: string;
  image: string;
  nutrition: Record<string, number | null>;
  ingredients: string[];
  ingredientsText: string;
  allergens: string[];
  traces: string[];
  ingredientsAnalysisTags: string[];
  servingSize: string;
  quantity: string;
  nutriscore: string | null;
  novaGroup: number | null;
  source: "open_food_facts";
  sourceFetchedAt: string;
  dataCompleteness: number;
  schemaVersion: 2;
  isOfflineCopy?: boolean;
}

function text(value: unknown, max = 500): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function number(value: unknown, max = Number.POSITIVE_INFINITY, min = 0): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max ? parsed : null;
}

function tags(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
      .map((item) => item.replace(/^\w+:/, "").replace(/-/g, " ").trim().toLowerCase())
      .filter(Boolean).slice(0, 100)
    : [];
}

/** Sole Open Food Facts to canonical-product conversion. Missing never means zero. */
export function normalizeOpenFoodFacts(raw: Record<string, any>, barcode: string): ProductFacts {
  const n = raw.nutriments ?? {};
  const energyKcal = number(n["energy-kcal_100g"], 1000);
  const energyKj = number(n["energy_100g"], 4184);
  const sodiumGrams = number(n["sodium_100g"], 100);
  const sodiumMg = sodiumGrams === null ? null : Math.round(sodiumGrams * 1000000) / 1000;
  const ingredientsText = text(raw.ingredients_text, 20000);
  const calories = energyKcal ?? (energyKj === null ? null : Math.round(energyKj / 4.184));
  const protein = number(n["proteins_100g"], 100);
  const carbs = number(n["carbohydrates_100g"], 100);
  const sugar = number(n["sugars_100g"], 100);
  const fat = number(n["fat_100g"], 100);
  const fiber = number(n["fiber_100g"], 100);
  const nutrition = {
    energyKcalPer100g: calories, proteinGPer100g: protein,
    carbohydratesGPer100g: carbs, sugarGPer100g: sugar,
    fatGPer100g: fat, fiberGPer100g: fiber, sodiumMgPer100g: sodiumMg,
    // Legacy UI keys retain the same canonical units.
    calories, protein, carbs, sugar, fat, fiber, sodium: sodiumMg,
  };
  const allergens = tags(raw.allergens_tags);
  const traces = tags(raw.traces_tags);
  const present = [!!text(raw.product_name), !!ingredientsText, allergens.length > 0 || traces.length > 0,
    calories !== null, protein !== null, sugar !== null, fat !== null, sodiumMg !== null,
    !!text(raw.image_front_url)].filter(Boolean).length;
  return {
    barcode, name: text(raw.product_name) || "Unnamed product", brand: text(raw.brands),
    category: text(raw.categories), image: text(raw.image_front_url) || text(raw.image_url),
    nutrition,
    ingredients: ingredientsText.split(",").map((part) => part.trim()).filter(Boolean).slice(0, 100),
    ingredientsText, allergens, traces,
    ingredientsAnalysisTags: tags(raw.ingredients_analysis_tags),
    servingSize: text(raw.serving_size), quantity: text(raw.quantity),
    nutriscore: text(raw.nutriscore_grade) || null,
    novaGroup: number(raw.nova_group, 4, 1), source: "open_food_facts",
    sourceFetchedAt: new Date().toISOString(),
    dataCompleteness: Math.round((present / 9) * 100) / 100, schemaVersion: 2,
  };
}
