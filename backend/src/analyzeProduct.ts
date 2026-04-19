import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import Groq from "groq-sdk";

// Ensure admin is initialised exactly once across all function files.
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const groqApiKeySecret = defineSecret("GROQ_API_KEY");

// ──────────────────────── Open Food Facts helpers ────────────────────────

interface ParsedProduct {
  barcode: string;
  name: string;
  brand: string;
  category: string;
  image: string;
  nutrition: Record<string, number>;
  ingredients: string[];
  allergens: string[];
  servingSize: string;
  nutriscore: string | null;
  novaGroup: number | null;
  quantity: string;
}

async function fetchFromOpenFoodFacts(barcode: string): Promise<ParsedProduct | null> {
  const fetch = (await import("node-fetch")).default;

  const url = `https://world.openfoodfacts.org/api/v2/product/${barcode}.json`;
  const res = await fetch(url, {
    headers: { "User-Agent": "FoodInsightScanner/1.0 (CloudFunction)" },
  });

  if (!res.ok) return null;

  const json = (await res.json()) as any;
  if (json.status !== 1 || !json.product) return null;

  const raw = json.product;
  const nutriments = raw.nutriments ?? {};

  return {
    barcode,
    name: raw.product_name ?? "Unknown Product",
    brand: raw.brands ?? "Unknown Brand",
    category: raw.categories ?? "Uncategorized",
    image: raw.image_front_url ?? raw.image_url ?? "",
    nutrition: {
      calories: nutriments["energy-kcal_100g"] ?? 0,
      sugar: nutriments["sugars_100g"] ?? 0,
      protein: nutriments["proteins_100g"] ?? 0,
      sodium: nutriments["sodium_100g"] ?? 0,
      fiber: nutriments["fiber_100g"] ?? 0,
      fat: nutriments["fat_100g"] ?? 0,
      carbs: nutriments["carbohydrates_100g"] ?? 0,
    },
    ingredients: (raw.ingredients_text ?? "")
      .split(",")
      .map((s: string) => s.trim())
      .filter((s: string) => s.length > 0),
    allergens: (raw.allergens_tags ?? []).map((t: string) => t.replace("en:", "")),
    servingSize: raw.serving_size ?? "Per 100g",
    nutriscore: raw.nutriscore_grade ?? null,
    novaGroup: raw.nova_group ?? null,
    quantity: raw.quantity ?? "",
  };
}

// ──────────────────────── AI Analysis ────────────────────────

async function conductHealthAnalysis(groq: Groq, product: ParsedProduct): Promise<any> {
  const completion = await groq.chat.completions.create({
    model: "llama3-8b-8192", // Fast JSON capable model, or the one you want
    messages: [
      {
        role: "system",
        content: `You are an expert nutritionist. Provide a strict health analysis of the scanned product and format your response ONLY as valid JSON.
{
  "summary": "2-3 sentences concise health analysis mentioning positives and negatives",
  "isHealthy": boolean,
  "warnings": ["Array of short warnings if any"]
}`,
      },
      {
        role: "user",
        content: `Analyze: ${product.name} by ${product.brand}.\nNutrition per 100g: ${JSON.stringify(product.nutrition)}\nIngredients: ${product.ingredients.join(", ")}`,
      },
    ],
    temperature: 0.2,
    max_tokens: 256,
    response_format: { type: "json_object" },
  });

  const content = completion.choices?.[0]?.message?.content ?? "{}";
  try {
    return JSON.parse(content);
  } catch(e) {
    return { summary: content, isHealthy: false, warnings: [] };
  }
}

// ──────────────────────── Callable Function ────────────────────────

export const analyzeProduct = onCall(
  { region: "asia-south1", timeoutSeconds: 30, secrets: [groqApiKeySecret] },
  async (request) => {
    // Require authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const barcode = request.data?.barcode as string | undefined;
    if (!barcode || typeof barcode !== "string" || barcode.length < 4) {
      throw new HttpsError("invalid-argument", "A valid barcode is required.");
    }

    // 1. Check Firestore cache
    const cacheRef = db.collection("products").doc(barcode);
    const cached = await cacheRef.get();
    if (cached.exists) {
      return cached.data();
    }

    // 2. Fetch from Open Food Facts
    const product = await fetchFromOpenFoodFacts(barcode);
    if (!product) {
      throw new HttpsError("not-found", `Product not found for barcode: ${barcode}`);
    }

    // 3. AI analysis
    let aiAnalysis = {};
    try {
      const apiKey = groqApiKeySecret.value();
      if (!apiKey) throw new Error("GROQ_API_KEY is not set.");
      const groq = new Groq({ apiKey });
      
      aiAnalysis = await conductHealthAnalysis(groq, product);
    } catch (e: any) {
      console.warn("AI analysis failed (non-fatal):", e.message);
      aiAnalysis = { summary: "AI analysis unavailable.", isHealthy: false, warnings: [] };
    }

    // 4. Cache in Firestore (Admin SDK bypasses security rules)
    const result = { ...product, aiAnalysis, lastUpdated: admin.firestore.FieldValue.serverTimestamp() };
    await cacheRef.set(result, { merge: true });

    return result;
  }
);
