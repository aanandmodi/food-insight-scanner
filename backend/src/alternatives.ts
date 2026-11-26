import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { assertAccountActive } from './accountStatus';
import { normalizeOpenFoodFacts } from './productNormalizer';
if (!getApps().length) initializeApp();
const db = getFirestore();

export const alternatives = onCall({region:'asia-south1',enforceAppCheck:true,timeoutSeconds:30},async request => {
  if (!request.auth) throw new HttpsError('unauthenticated','Sign in to compare products.');
  await assertAccountActive(db, request.auth.uid);
  if ((await db.doc('config/featureFlags').get()).data()?.alternativesEnabled !== true) return {candidates:[]};
  const barcode = request.data?.barcode;
  if (typeof barcode !== 'string' || !/^\d{8,14}$/.test(barcode)) throw new HttpsError('invalid-argument','Invalid barcode.');
  // Category comes exclusively from an existing normalized OFF record, not the caller.
  const product = (await db.doc(`products/${barcode}`).get()).data();
  const tagsRaw = Array.isArray(product?.categoryTags) ? product.categoryTags : [];
  const candidateCategories = [tagsRaw.at(-1), tagsRaw.at(-2)]
    .filter((tag): tag is string => typeof tag === 'string' && /^en:[a-z0-9-]{1,100}$/.test(tag));
  const uniqueCategories = Array.from(new Set(candidateCategories));
  const category = uniqueCategories[0];
  if (!category) return {candidates:[]};
  const ref = db.doc(`alternativeCategories/${category}`);
  const cached = (await ref.get()).data();
  if (cached && Array.isArray(cached.candidates) && cached.candidates.length > 0 && Date.now() - Number(cached.fetchedAt) < 7 * 86400000) {
    return {candidates:cached.candidates};
  }
  const quota = db.doc('serviceLimits/offSearch');
  const minute = Math.floor(Date.now()/60000);
  const day = new Date().toISOString().slice(0,10);
  await db.runTransaction(async tx => {
    const data = (await tx.get(quota)).data() ?? {};
    const count = data.minute === minute ? Number(data.count)||0 : 0;
    const daily = data.day === day ? Number(data.daily)||0 : 0;
    if (count >= 5 || daily >= 100) throw new HttpsError('resource-exhausted','Product comparisons are busy. Please retry later.');
    tx.set(quota,{minute,count:count+1,day,daily:daily+1});
  });
  const fields = 'code,product_name,brands,categories,categories_tags,image_front_url,nutriments,ingredients_text,allergens_tags,traces_tags,ingredients_analysis_tags,serving_size,quantity,nutriscore_grade,nova_group,additives_tags';
  const fetchCategory = async (cat: string): Promise<any[]> => {
    const query = new URLSearchParams({categories_tags:cat,countries_tags:'en:india',page_size:'20',fields});
    let lastErr: unknown;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const response = await fetch(`https://world.openfoodfacts.org/api/v2/search?${query}`,{
          headers:{'User-Agent':'FoodInsightScanner/1.0 (aanandmodi09@gmail.com)'},signal:AbortSignal.timeout(15000)});
        if (!response.ok) throw Error(`Lookup failed: ${response.status}`);
        const payload = await response.json() as any;
        if (!Array.isArray(payload.products)) throw Error('Invalid catalog');
        return payload.products.slice(0,20)
          .filter((p: any) => typeof p.code === 'string' && /^\d{8,14}$/.test(p.code) && p.categories_tags?.includes(cat))
          .map((p: any) => normalizeOpenFoodFacts(p,p.code));
      } catch (err) {
        lastErr = err;
        if (attempt === 0) await new Promise((r) => setTimeout(r, 500));
      }
    }
    throw lastErr;
  };
  try {
    let candidates: any[] = [];
    for (const cat of uniqueCategories) {
      try {
        const rows = await fetchCategory(cat);
        if (rows.length > 0) {
          candidates = rows;
          break;
        }
      } catch {
        // Try broader parent category tag before failing.
      }
    }
    if (candidates.length === 0) {
      candidates = await fetchCategory(category);
    }
    await ref.set({fetchedAt:Date.now(),candidates});
    return {candidates};
  } catch {
    throw new HttpsError('unavailable','Verified alternatives could not be loaded. Please retry later.');
  }
});
