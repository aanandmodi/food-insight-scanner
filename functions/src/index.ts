/**
 * Cloud Functions entry point for Food Insight Scanner.
 *
 * All AI and external API logic is centralized here so the mobile client
 * never touches the Groq API key or writes directly to the shared
 * products collection.
 */

export { scanProduct } from "./scanProduct";
export { parseMeal } from "./parseMeal";
export { generateDietPlan } from "./generateDietPlan";
export { getAlternatives } from "./getAlternatives";
export { chatWithAI } from "./chatWithAI";
export { generateQuickReplies } from "./generateQuickReplies";
