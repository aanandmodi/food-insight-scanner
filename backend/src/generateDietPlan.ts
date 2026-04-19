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
 * generateDietPlan – Creates a next-day meal plan based on today's intake
 * and the user's profile.
 *
 * Input:  { dailySummary: { calories, protein, sugar }, userProfile?: object }
 * Output: { summary, meals: [...], totalCalories, totalProtein }
 */
export const generateDietPlan = onCall(
  { region: "asia-south1", timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const { dailySummary, userProfile } = request.data ?? {};
    if (!dailySummary) {
      throw new HttpsError("invalid-argument", "dailySummary is required.");
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
    } catch {
      throw new HttpsError("internal", "AI returned unparseable diet plan. Please retry.");
    }
  }
);
