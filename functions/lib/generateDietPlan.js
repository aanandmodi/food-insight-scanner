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
exports.generateDietPlan = void 0;
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
 * generateDietPlan – Creates a next-day meal plan based on today's intake
 * and the user's profile.
 *
 * Input:  { dailySummary: { calories, protein, sugar }, userProfile?: object }
 * Output: { summary, meals: [...], totalCalories, totalProtein }
 */
exports.generateDietPlan = (0, https_1.onCall)({ region: "asia-south1", timeoutSeconds: 30 }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be logged in.");
    }
    const { dailySummary, userProfile } = request.data ?? {};
    if (!dailySummary) {
        throw new https_1.HttpsError("invalid-argument", "dailySummary is required.");
    }
    const groq = getGroqClient();
    const prompt = `Create a detailed meal plan for TOMORROW based on my intake today and my goals.

Today's Intake Summary:
- Calories: ${dailySummary.calories ?? 0}
- Protein: ${dailySummary.protein ?? 0}g
- Sugar: ${dailySummary.sugar ?? 0}g

My Profile:
${userProfile ? JSON.stringify(userProfile) : "None"}

Output strictly a JSON object with this structure:
{
  "summary": "Short overview text...",
  "meals": [
    { "type": "Breakfast", "name": "...", "calories": 300, "protein": 10, "description": "..." },
    { "type": "Lunch",     "name": "...", "calories": 500, "protein": 25, "description": "..." },
    { "type": "Dinner",    "name": "...", "calories": 600, "protein": 30, "description": "..." },
    { "type": "Snack",     "name": "...", "calories": 150, "protein": 5,  "description": "..." }
  ],
  "totalCalories": 1550,
  "totalProtein": 70
}`;
    const completion = await groq.chat.completions.create({
        model: "meta-llama/llama-4-scout-17b-16e-instruct",
        messages: [
            {
                role: "system",
                content: "You are a nutritionist. Create a meal plan for the next day. Output strictly valid JSON. No markdown.",
            },
            { role: "user", content: prompt },
        ],
        temperature: 0.7,
        max_tokens: 1500,
    });
    const raw = completion.choices?.[0]?.message?.content ?? "{}";
    const cleaned = raw.replace(/```json\s*/g, "").replace(/```/g, "").trim();
    try {
        return JSON.parse(cleaned);
    }
    catch {
        throw new https_1.HttpsError("internal", "AI returned unparseable diet plan. Please retry.");
    }
});
//# sourceMappingURL=generateDietPlan.js.map