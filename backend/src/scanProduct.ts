import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Groq from "groq-sdk";

// Ensure admin is initialised exactly once across all function files.
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/** Groq client – reads the key from the Cloud Functions environment. */
function getGroqClient(): Groq {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "GROQ_API_KEY is not configured on the server.");
  }
  return new Groq({ apiKey });
}

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
  // Dynamic import for node-fetch (CommonJS compat)
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

async function analyzeProduct(groq: Groq, product: ParsedProduct): Promise<string> {
  const completion = await groq.chat.completions.create({
    model: "meta-llama/llama-4-scout-17b-16e-instruct",
    messages: [
      {
        role: "system",
        content:
          "You are an expert nutritionist. Provide a concise health analysis of the scanned product in 2-3 sentences. Mention positives and negatives.",
      },
      {
        role: "user",
        content: `Analyze: ${product.name} by ${product.brand}.\nNutrition per 100g: ${JSON.stringify(product.nutrition)}\nIngredients: ${product.ingredients.join(", ")}`,
      },
    ],
    temperature: 0.5,
    max_tokens: 256,
  });

  return completion.choices?.[0]?.message?.content ?? "";
}

// ──────────────────────── Callable Function ────────────────────────

/**
 * scanProduct – looks up a barcode, caches in Firestore, returns product data.
 *
 * Input:  { barcode: string }
 * Output: ParsedProduct & { aiAnalysis: string }
 */
export const scanProduct = onCall(
  { region: "asia-south1", timeoutSeconds: 30 },
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
    let aiAnalysis = "";
    try {
      const groq = getGroqClient();
      aiAnalysis = await analyzeProduct(groq, product);
    } catch (e: any) {
      console.warn("AI analysis failed (non-fatal):", e.message);
    }

    // 4. Cache in Firestore (Admin SDK bypasses security rules)
    const result = { ...product, aiAnalysis, lastUpdated: admin.firestore.FieldValue.serverTimestamp() };
    await cacheRef.set(result, { merge: true });

    return result;
  }
);
