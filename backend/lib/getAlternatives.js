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
exports.getAlternatives = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const groq_sdk_1 = __importDefault(require("groq-sdk"));
if (!admin.apps.length) {
    admin.initializeApp();
}
function getGroqClient() {
    const apiKey = process.env.GROQ_API_KEY;
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "GROQ_API_KEY is not configured on the server.");
    }
    return new groq_sdk_1.default({ apiKey });
}
/**
 * getAlternatives – Suggests healthier Indian-market alternatives for a product.
 *
 * Input:  { productData: { name, brand, ... }, userProfile?: object }
 * Output: { alternatives: [{ name, brand, image, isBetterChoice, healthScore, price }] }
 */
exports.getAlternatives = (0, https_1.onCall)({ region: "asia-south1", timeoutSeconds: 20 }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be logged in.");
    }
    const { productData, userProfile } = request.data ?? {};
    if (!productData?.name) {
        throw new https_1.HttpsError("invalid-argument", "productData with a name is required.");
    }
    const groq = getGroqClient();
    const prompt = `Based on this product: "${productData.name}" (Brand: ${productData.brand ?? "Unknown"}), suggest 3 healthier alternatives specifically available in the **Indian Market**.

User Context:
${userProfile ? JSON.stringify(userProfile) : "None"}

Output strictly a JSON object. Each object must have:
- "name": string (Indian product name)
- "brand": string (Popular Indian brands like Amul, Britannia, Tata Sampann, Yoga Bar, etc.)
- "image": string (use a placeholder URL like "https://placehold.co/200x200?text=Healthy+Choice")
- "isBetterChoice": boolean (always true)
- "healthScore": number (80-100)
- "price": string (estimate realistic price in INR, e.g. "₹45.00" or "Rs. 150")

Example format:
{
  "alternatives": [
    {"name": "...", "brand": "...", "image": "...", "isBetterChoice": true, "healthScore": 90, "price": "₹120"}
  ]
}`;
    const completion = await groq.chat.completions.create({
        model: "meta-llama/llama-4-scout-17b-16e-instruct",
        messages: [
            {
                role: "system",
                content: "You are a nutritionist. Suggest healthier food alternatives as a strict JSON object with an 'alternatives' array. No markdown.",
            },
            { role: "user", content: prompt },
        ],
        temperature: 0.6,
        max_tokens: 1024,
    });
    const raw = completion.choices?.[0]?.message?.content ?? "{}";
    const cleaned = raw.replace(/```json\s*/g, "").replace(/```/g, "").trim();
    try {
        const parsed = JSON.parse(cleaned);
        // Normalise: accept both { alternatives: [...] } and bare [...]
        if (Array.isArray(parsed)) {
            return { alternatives: parsed };
        }
        if (parsed.alternatives && Array.isArray(parsed.alternatives)) {
            return { alternatives: parsed.alternatives };
        }
        return { alternatives: [] };
    }
    catch {
        return { alternatives: [] };
    }
});
//# sourceMappingURL=getAlternatives.js.map