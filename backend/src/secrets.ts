import { defineSecret } from "firebase-functions/params";

export const groqApiKey = defineSecret("GROQ_API_KEY");
export const supabaseAdminKey = defineSecret("SUPABASE_SERVICE_ROLE_KEY");

/**
 * Reads a Firebase SecretParam safely without crashing unit tests or offline
 * environments where the secret environment variable is not populated.
 */
export function readSecretOrEnv(
  secret: { value: () => string },
  envName: string,
): string | undefined {
  const fromEnv = process.env[envName]?.trim();
  if (fromEnv) return fromEnv;
  try {
    const val = secret.value()?.trim();
    return val || undefined;
  } catch {
    return undefined;
  }
}
