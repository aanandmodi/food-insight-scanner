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
exports.generateQuickReplies = void 0;
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
 * generateQuickReplies – Returns context-aware quick-reply suggestions.
 *
 * Input:  { lastMessage: string, userProfile?: object }
 * Output: { replies: string[] }
 */
exports.generateQuickReplies = (0, https_1.onCall)({ region: "asia-south1", timeoutSeconds: 15 }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "You must be logged in.");
    }
    const { lastMessage, userProfile } = request.data ?? {};
    if (!lastMessage || typeof lastMessage !== "string") {
        return { replies: ["Help me with my diet", "What are some healthy snacks?", "Analyze my last meal", "Calorie breakdown"] };
    }
    try {
        const groq = getGroqClient();
        const prompt = `Based on the user's last message and profile, suggest 4 relevant quick reply options for a nutrition assistant app.\n\n` +
            `User's last message: "${lastMessage}"\n` +
            `${userProfile ? "User Profile: " + JSON.stringify(userProfile) : ""}\n\n` +
            `Generate 4 short, actionable quick-reply suggestions.\n` +
            `Return ONLY the suggestions, one per line, without numbering or bullets.`;
        const completion = await groq.chat.completions.create({
            model: "meta-llama/llama-4-scout-17b-16e-instruct",
            messages: [
                {
                    role: "system",
                    content: "You are a helpful nutrition assistant. Respond with only 4 suggestions, one per line.",
                },
                { role: "user", content: prompt },
            ],
            temperature: 0.8,
            max_tokens: 256,
        });
        const text = completion.choices?.[0]?.message?.content ?? "";
        const replies = text
            .split("\n")
            .map((l) => l.trim())
            .filter((l) => l.length > 0)
            .slice(0, 4);
        return { replies: replies.length > 0 ? replies : ["Healthy snack ideas", "Check ingredients", "Nutrition advice", "Calorie breakdown"] };
    }
    catch (e) {
        console.warn("Quick replies generation failed:", e.message);
        return { replies: ["Healthy snack ideas", "Check ingredients", "Nutrition advice", "Calorie breakdown"] };
    }
});
//# sourceMappingURL=generateQuickReplies.js.map