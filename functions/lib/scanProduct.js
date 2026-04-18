"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.scanProduct = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const groq_sdk_1 = __importDefault(require("groq-sdk"));
// Ensure admin is initialised exactly once across all function files.
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/** Groq client – reads the key from the Cloud Functions environment. */
function getGroqClient() {
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "GROQ_API_KEY is not configured on the server.");
    }
    return new groq_sdk_1.default({ apiKey });
}
async function fetchFromOpenFoodFacts(barcode) {
    // Dynamic import for node-fetch (CommonJS compat)
    const fetch = (await Promise.resolve().then(() => __importStar(require("node-fetch")))).default;
    const url = `https://world.openfoodfacts.org/api/v2/product/${barcode}.json`;
    const res = await fetch(url, {
        headers: { "User-Agent": "FoodInsightScanner/1.0 (CloudFunction)" },
    });
    if (!res.ok)
        return null;
    const json = (await res.json());
    if (json.status !== 1 || !json.product)
        return null;
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
            .map((s) => s.trim())
            .filter((s) => s.length > 0),
        allergens: (raw.allergens_tags ?? []).map((t) => t.replace("en:", "")),
        servingSize: raw.serving_size ?? "Per 100g",
        nutriscore: raw.nutriscore_grade ?? null,
        novaGroup: raw.nova_group ?? null,
        quantity: raw.quantity ?? "",
    };
}
// ──────────────────────── AI Analysis ────────────────────────
async function analyzeProduct(groq, product) {
    const completion = await groq.chat.completions.create({
        model: "meta-llama/llama-4-scout-17b-16e-instruct",
        messages: [
            {
                role: "system",
                content: "You are an expert nutritionist. Provide a concise health analysis of the scanned product in 2-3 sentences. Mention positives and negatives.",
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
exports.scanProduct = (0, https_1.onCall)({ region: "asia-south1", timeoutSeconds: 30 }, async (request) => {
    // Require authentication
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be logged in.");
    }
    const barcode = request.data?.barcode;
    if (!barcode || typeof barcode !== "string" || barcode.length < 4) {
        throw new https_1.HttpsError("invalid-argument", "A valid barcode is required.");
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
        throw new https_1.HttpsError("not-found", `Product not found for barcode: ${barcode}`);
    }
    // 3. AI analysis
    let aiAnalysis = "";
    try {
        const groq = getGroqClient();
        aiAnalysis = await analyzeProduct(groq, product);
    }
    catch (e) {
        console.warn("AI analysis failed (non-fatal):", e.message);
    }
    // 4. Cache in Firestore (Admin SDK bypasses security rules)
    const result = { ...product, aiAnalysis, lastUpdated: admin.firestore.FieldValue.serverTimestamp() };
    await cacheRef.set(result, { merge: true });
    return result;
});
//# sourceMappingURL=scanProduct.js.map