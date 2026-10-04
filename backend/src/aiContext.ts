import { AiTask, boundedNumber, boundedString, profileData } from './aiValidation';
import { Buffer } from 'node:buffer';

const nutrients = ['calories','protein','carbs','fat','sugar','sodium'];
function object(v: any): Record<string, any> {
  if (v === undefined || v === null) return {};
  if (typeof v !== 'object' || Array.isArray(v)) throw Error('Invalid context');
  return v;
}
function numbers(v: any, fields: string[], signed = false): Record<string, number | null> {
  const input = object(v);
  return Object.fromEntries(fields.filter(k => k in input).map(k => {
    const value = input[k];
    if (value == null) return [k,null];
    if (typeof value !== 'number') throw Error('Invalid numeric context');
    boundedNumber(signed ? Math.abs(value) : value,k,100000);
    return [k,value];
  }));
}

/** Rebuild device context at the trust boundary; discard identity/unknown fields. */
export function nutritionContext(task: AiTask, value: unknown): Record<string, unknown> {
  const input = object(value);
  if (Buffer.byteLength(JSON.stringify(input)) > 14000) throw Error('Context too large');
  const profile = profileData(input.profile);
  if (task === 'meal') return { profile: Object.fromEntries(['country','region','dietaryPreferences']
    .filter(k => profile[k] !== undefined).map(k => [k,profile[k]])) };
  const today = object(input.today);
  const output: Record<string, unknown> = { profile,
    units:'calories=kcal; sodium=mg; other nutrients=g. Intake describes logs, not proof of total consumption.',
    targets:numbers(input.targets,nutrients),
    today:{...numbers(today,[...nutrients,'entriesLogged']), remaining:numbers(today.remaining,nutrients,true)} };
  if (task === 'chat' || task === 'macros') {
    const seven = object(input.sevenDay);
    output.sevenDay = {...numbers(seven,['daysLogged',...nutrients.map(k => 'average'+k[0].toUpperCase()+k.slice(1))]),
      confidence: Number(seven.daysLogged) < 3 ? 'low' : 'partial',
      note:'Logged intake only. Incomplete logging is not evidence of undereating.'};
    const activity = object(input.activity);
    if (['healthConnect','pedometerEstimate'].includes(activity.source)) {
      output.activity = {...numbers(activity,['steps','activeCalories']),source:activity.source};
    }
  }
  if (task === 'chat' || task === 'plan') {
    if (input.recentMeals !== undefined && !Array.isArray(input.recentMeals)) throw Error('Invalid meals');
    output.recentMeals = (input.recentMeals ?? []).slice(0,8).map((v: any) => ({
      ...numbers(v,nutrients),name:boundedString(v.name,160,true) }));
  }
  if (task === 'chat') {
    if (input.recentScans !== undefined && !Array.isArray(input.recentScans)) throw Error('Invalid scans');
    output.recentScans = (input.recentScans ?? []).slice(0,5).map((v: any) => ({
      name: boundedString(v.productName ?? v.name,160,true),
      nutrition: numbers(v.nutrition,[...nutrients,'energyKcalPer100g','proteinGPer100g','carbohydratesGPer100g','fatGPer100g','sugarGPer100g','sodiumMgPer100g','fiberGPer100g']),
      ingredientsText:boundedString(v.ingredientsText,1600,true),
    }));
  }
  return output;
}
