import { boundedNumber } from './aiValidation';

/** Product guardrails, not clinical recommendations. Existing targets are the baseline. */
export function macroBaseline(context: Record<string, any>) {
  const age = context.profile?.age;
  if (typeof age !== 'number' || age < 18) throw Error('Adult profile required');
  const targets = context.targets ?? {};
  const baseline: Record<string, number> = {};
  const ranges: Record<string, [number,number]> = {
    calories:[1500,4000], protein:[30,300], carbs:[100,600], fat:[35,180],
  };
  for (const [key,[min,max]] of Object.entries(ranges)) {
    const v = boundedNumber(targets[key],key,max);
    if (v < min) throw Error('Targets outside general wellness scope');
    baseline[key] = v;
  }
  return baseline;
}

export function validateMacroAdjustment(value: Record<string, any>, context: Record<string, any>, maxPercent: unknown = 10) {
  const baseline = macroBaseline(context);
  const limit = typeof maxPercent === 'number' && Number.isFinite(maxPercent)
    ? Math.max(0, Math.min(10,maxPercent)) / 100 : 0.1;
  const days = context.sevenDay?.daysLogged ?? 0;
  if (days < 3) return {...baseline,
    explanation:'Low confidence: fewer than three days contain logs. Keep your current targets. Incomplete logging is not evidence of undereating.'};
  for (const key of Object.keys(baseline)) {
    if (Math.abs(value[key] - baseline[key]) > baseline[key] * limit + 0.01) throw Error('Adjustment exceeds bounds');
  }
  macroBaseline({...context,targets:value});
  return {...value, explanation:`Based on ${days} days with logs; completeness is unknown. ${value.explanation}`};
}
