import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Groq from "groq-sdk";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function getGroqClient(): Groq {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "GROQ_API_KEY is not configured on the server.");
  }
  return new Groq({ apiKey });
}

/**
 * chatWithAI – Sends a message to the Groq nutrition assistant and returns
 * the reply.  If the AI auto-logs a meal via [LOG_MEAL: {...}], the
 * function writes the entry to Firestore and strips the tag from the
 * response sent back to the client.
 *
 * Input:  { message, conversationHistory?, userProfile? }
 * Output: { reply: string, mealLogged: boolean, mealData?: object }
 */
export const chatWithAI = onCall(
  { region: "asia-south1", timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const { message, conversationHistory, userProfile } = request.data ?? {};
    if (!message || typeof message !== "string" || message.trim().length === 0) {
      throw new HttpsError("invalid-argument", "A message is required.");
    }

    const groq = getGroqClient();

    // Build system prompt
    let systemPrompt = `You are an energetic, friendly, and expert nutrition assistant for an Indian food insight scanner app. Your role is to provide personalized dietary advice in a warm, humanized, and highly conversational tone.

**Your Personality & Formatting Rules:**
- **Be Conversational & Energetic:** Talk to the user like a helpful friend. Use fun emojis! 🥑🚀🥗
- **Visual Formatting:** Whenever comparing products or breaking down macros (Calories, Protein, Carbs, Fat), always use **Markdown Tables**.
- **Keep it Clear:** Use bullet points and short, readable paragraphs.
- **Prioritize Safety:** Always warn about allergens and dietary restrictions.

**CRITICAL: Meal Logging Detection**
If the user tells you they just ate something (e.g. "I just had a masala dosa" or "I ate an apple"), you must do TWO things:
1. Respond to them normally in a friendly way.
2. At the very END of your response, output a strict JSON block exactly in this format on its own line:
[LOG_MEAL: {"name": "Meal Name", "calories": 250, "protein": 5, "sugar": 2, "fat": 10, "carbs": 30}]
Never use markdown blocks for the JSON. Just output the exact text string format above so it can be silently logged.`;

    if (userProfile) {
      systemPrompt += "\n--- User Profile Context ---\n";
      if (userProfile.name) systemPrompt += `- Name: ${userProfile.name}\n`;
      if (userProfile.allergies?.length) {
        systemPrompt += `- Allergies: ${userProfile.allergies.join(", ")}\n`;
        systemPrompt += "- IMPORTANT: Always warn about these allergens.\n";
      }
      if (userProfile.dietaryPreferences) {
        systemPrompt += `- Dietary Preference: ${userProfile.dietaryPreferences}\n`;
      }
      if (userProfile.healthGoals) {
        systemPrompt += `- Health Goals: ${userProfile.healthGoals}\n`;
      }
    }

    // Build messages array
    const messages: Array<{ role: "system" | "user" | "assistant"; content: string }> = [
      { role: "system", content: systemPrompt },
    ];

    // Parse conversation history
    if (conversationHistory && typeof conversationHistory === "string") {
      const lines = conversationHistory.split("\n");
      for (const line of lines) {
        if (line.startsWith("User: ")) {
          messages.push({ role: "user", content: line.substring(6) });
        } else if (line.startsWith("Assistant: ")) {
          messages.push({ role: "assistant", content: line.substring(11) });
        }
      }
    }

    messages.push({ role: "user", content: message });

    const completion = await groq.chat.completions.create({
      model: "meta-llama/llama-4-scout-17b-16e-instruct",
      messages,
      temperature: 0.7,
      max_tokens: 1024,
      top_p: 0.95,
    });

    let reply = completion.choices?.[0]?.message?.content ?? "I apologize, but I could not generate a response.";

    // Extract LOG_MEAL intent
    let mealLogged = false;
    let mealData: Record<string, any> | undefined;

    const logMatch = reply.match(/\[LOG_MEAL:\s*(\{.*?\})\s*\]/s);
    if (logMatch) {
      try {
        const macros = JSON.parse(logMatch[1]);
        const now = new Date();
        const dateString = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
        const timeString = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;

        const entry = {
          name: macros.name ?? "AI Logged Meal",
          mealType: "Snack",
          calories: Number(macros.calories) || 0,
          protein: Number(macros.protein) || 0,
          sugar: Number(macros.sugar) || 0,
          fat: Number(macros.fat) || 0,
          carbs: Number(macros.carbs) || 0,
          brand: "Conversational AI",
          time: timeString,
          date: dateString,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        const uid = request.auth.uid;
        await db.collection("diet_log").doc(uid).collection("entries").add(entry);

        mealLogged = true;
        mealData = { ...entry, createdAt: undefined }; // Don't send FieldValue to client

        // Strip the tag from the reply
        reply = reply.replace(logMatch[0], "").trim();
      } catch (e: any) {
        console.warn("Failed to parse LOG_MEAL intent:", e.message);
      }
    }

    return { reply, mealLogged, mealData };
  }
);
