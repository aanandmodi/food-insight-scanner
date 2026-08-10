import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import Groq from "groq-sdk";

if (!admin.apps.length) {
  admin.initializeApp();
}

const groqApiKeySecret = defineSecret("GROQ_API_KEY");

/**
 * getAlternatives – Suggests healthier Indian-market alternatives for a product.
 *
 * Input:  { productData: { name, brand, ... }, userProfile?: object }
 * Output: { alternatives: [{ name, brand, image, isBetterChoice, healthScore, price }] }
 */
export const getAlternatives = onCall(
  { region: "asia-south1", timeoutSeconds: 20, secrets: [groqApiKeySecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be logged in.");
    }

    const { productData, userProfile } = request.data ?? {};
    if (!productData?.name) {
      throw new HttpsError("invalid-argument", "productData with a name is required.");
    }

    const apiKey = groqApiKeySecret.value();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "GROQ_API_KEY is not configured on the server.");
    }
    const groq = new Groq({ apiKey });

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
      model: "llama-3.3-70b-versatile",
      messages: [
        {
          role: "system",
          content:
            "You are a nutritionist. Suggest healthier food alternatives as a strict JSON object with an 'alternatives' array. No markdown.",
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
    } catch {
      return { alternatives: [] };
    }
  }
);
