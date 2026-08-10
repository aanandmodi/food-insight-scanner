import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import Groq from "groq-sdk";

if (!admin.apps.length) {
  admin.initializeApp();
}

const groqApiKeySecret = defineSecret("GROQ_API_KEY");

/**
 * parseMeal – Converts a natural-language meal description into structured
 * nutritional macros using Groq structured outputs.
 *
 * Input:  { description: string }
 * Output: { name, calories, protein, sugar, fat, carbs }
 */
export const parseMeal = onCall(
  { region: "asia-south1", timeoutSeconds: 20, secrets: [groqApiKeySecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const description = request.data?.description as string | undefined;
    if (!description || description.trim().length === 0) {
      throw new HttpsError("invalid-argument", "A meal description is required.");
    }

    const apiKey = groqApiKeySecret.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "GROQ_API_KEY is not configured on the server.");
    }
    const groq = new Groq({ apiKey });

    const completion = await groq.chat.completions.create({
      model: "llama-3.1-8b-instant",
      messages: [
        {
          role: "system",
          content:
            "You are a nutrition parser. Given a meal description, estimate the macronutrients for a typical Indian serving size. " +
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
    } catch {
      throw new HttpsError("internal", "AI returned unparseable response. Please try again.");
    }
  }
);
