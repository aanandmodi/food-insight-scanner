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
 * generateQuickReplies – Returns context-aware quick-reply suggestions.
 *
 * Input:  { lastMessage: string, userProfile?: object }
 * Output: { replies: string[] }
 */
export const generateQuickReplies = onCall(
  { region: "asia-south1", timeoutSeconds: 15 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const { lastMessage, userProfile } = request.data ?? {};
    if (!lastMessage || typeof lastMessage !== "string") {
      return { replies: ["Help me with my diet", "What are some healthy snacks?", "Analyze my last meal", "Calorie breakdown"] };
    }

    try {
      const groq = getGroqClient();

      const prompt =
        `Based on the user's last message and profile, suggest 4 relevant quick reply options for a nutrition assistant app.\n\n` +
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
        .map((l: string) => l.trim())
        .filter((l: string) => l.length > 0)
        .slice(0, 4);

      return { replies: replies.length > 0 ? replies : ["Healthy snack ideas", "Check ingredients", "Nutrition advice", "Calorie breakdown"] };
    } catch (e: any) {
      console.warn("Quick replies generation failed:", e.message);
      return { replies: ["Healthy snack ideas", "Check ingredients", "Nutrition advice", "Calorie breakdown"] };
    }
  }
);
