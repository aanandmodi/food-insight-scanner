import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { normalizeOpenFoodFacts, ProductFacts } from "./productNormalizer";

if (!getApps().length) initializeApp();
const db = getFirestore();
const BARCODE = /^\d{8,14}$/;

async function reserveOffLookup(): Promise<void> {
  // Open Food Facts documents a 15/minute/IP product-read limit. Keep room for
  // retries and avoid a burst of new barcodes from one beta backend IP.
  const ref = db.doc("serviceLimits/offLookupMinute");
  const minute = Math.floor(Date.now() / 60000);
  await db.runTransaction(async (transaction) => {
    const data = (await transaction.get(ref)).data() ?? {};
    const used = data.minute === minute ? Number(data.count) || 0 : 0;
    if (used >= 12) throw new HttpsError("resource-exhausted", "Product lookup is busy. Please try again shortly.");
    transaction.set(ref, { minute, count: used + 1 });
  });
}

export const scanProduct = onCall(
  { region: "asia-south1", timeoutSeconds: 20, enforceAppCheck: true, maxInstances: 3 },
  async (request): Promise<ProductFacts> => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to scan products.");
    if ((await db.doc(`accountDeletionGuards/${request.auth.uid}`).get()).exists) {
      throw new HttpsError("permission-denied", "Account deletion is in progress.");
    }
    const barcode = request.data?.barcode;
    if (typeof barcode !== "string" || !BARCODE.test(barcode)) {
      throw new HttpsError("invalid-argument", "Enter an 8–14 digit barcode.");
    }
    const ref = db.collection("products").doc(barcode);
    const cached = await ref.get();
    const cachedData = cached.data();
    const stale = cachedData?.schemaVersion === 2 &&
      cachedData?.nutrition?.sodiumMgPer100g !== undefined
      ? { ...cachedData, isOfflineCopy: true } as ProductFacts : null;
    const age = Date.now() - Date.parse(cachedData?.sourceFetchedAt ?? "");
    if (cachedData?.schemaVersion === 2 && age >= 0 && age < 7 * 86400000 &&
        cachedData?.nutrition?.sodiumMgPer100g !== undefined) {
      return cachedData as ProductFacts;
    }
    try {
      await reserveOffLookup();
    } catch (error) {
      if (stale) return stale;
      throw error;
    }
    let response: Response;
    try {
      response = await fetch(`https://world.openfoodfacts.org/api/v2/product/${barcode}.json`, {
        headers: { "User-Agent": "FoodInsightScanner/1.0 (aanandmodi09@gmail.com)" },
        signal: AbortSignal.timeout(12000),
      });
    } catch {
      if (stale) return stale;
      throw new HttpsError("unavailable", "Product lookup is temporarily unavailable.");
    }
    if (response.status === 404) throw new HttpsError("not-found", "Product not found in Open Food Facts.");
    if (!response.ok) {
      if (stale) return stale;
      throw new HttpsError("unavailable", "Product lookup is temporarily unavailable.");
    }
    let payload: { status?: number; product?: Record<string, any> };
    try {
      payload = await response.json() as { status?: number; product?: Record<string, any> };
    } catch {
      if (stale) return stale;
      throw new HttpsError("unavailable", "Product details could not be read.");
    }
    if (payload.status !== 1 || !payload.product) {
      throw new HttpsError("not-found", "Product not found in Open Food Facts.");
    }
    const product = normalizeOpenFoodFacts(payload.product, barcode);
    await ref.set(product);
    return product;
  },
);
