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
exports.parseMeal = void 0;
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
 * parseMeal – Converts a natural-language meal description into structured
 * nutritional macros using Groq structured outputs.
 *
 * Input:  { description: string }
 * Output: { name, calories, protein, sugar, fat, carbs }
 */
exports.parseMeal = (0, https_1.onCall)({ region: "asia-south1", timeoutSeconds: 20 }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be logged in.");
    }
    const description = request.data?.description;
    if (!description || description.trim().length === 0) {
        throw new https_1.HttpsError("invalid-argument", "A meal description is required.");
    }
    const groq = getGroqClient();
    const completion = await groq.chat.completions.create({
        model: "meta-llama/llama-4-scout-17b-16e-instruct",
        messages: [
            {
                role: "system",
                content: "You are a nutrition parser. Given a meal description, estimate the macronutrients for a typical Indian serving size. " +
                    "Return ONLY a valid JSON object with these exact keys: " +
                    '{"name": "Brief Meal Name", "calories": <int>, "protein": <number>, "sugar": <number>, "fat": <number>, "carbs": <number>}. ' +
                    "No markdown, no explanation, just the JSON object.",
            },
            {
                role: "user",
                content: `Analyze this meal: "${description}"`,
            },
        ],
        temperature: 0.1,
        max_tokens: 256,
    });
    const raw = completion.choices?.[0]?.message?.content ?? "";
    // Parse JSON from the response – strip markdown fences if present
    const cleaned = raw.replace(/```json\s*/g, "").replace(/```/g, "").trim();
    try {
        const parsed = JSON.parse(cleaned);
        return {
            name: parsed.name ?? description,
            calories: Number(parsed.calories) || 0,
            protein: Number(parsed.protein) || 0,
            sugar: Number(parsed.sugar) || 0,
            fat: Number(parsed.fat) || 0,
            carbs: Number(parsed.carbs) || 0,
        };
    }
    catch {
        throw new https_1.HttpsError("internal", "AI returned unparseable response. Please try again.");
    }
});
//# sourceMappingURL=parseMeal.js.map