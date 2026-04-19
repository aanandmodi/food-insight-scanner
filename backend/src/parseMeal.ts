import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Groq from "groq-sdk";

if (!admin.apps.length) {
  admin.initializeApp();
}

function getGroqClient(): Groq {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "GROQ_API_KEY is not configured on the server.");
  }
  return new Groq({ apiKey });
}

/**
 * parseMeal – Converts a natural-language meal description into structured
 * nutritional macros using Groq structured outputs.
 *
 * Input:  { description: string }
 * Output: { name, calories, protein, sugar, fat, carbs }
 */
export const parseMeal = onCall(
  { region: "asia-south1", timeoutSeconds: 20 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const description = request.data?.description as string | undefined;
    if (!description || description.trim().length === 0) {
      throw new HttpsError("invalid-argument", "A meal description is required.");
    }

    const groq = getGroqClient();

    const completion = await groq.chat.completions.create({
      model: "meta-llama/llama-4-scout-17b-16e-instruct",
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
