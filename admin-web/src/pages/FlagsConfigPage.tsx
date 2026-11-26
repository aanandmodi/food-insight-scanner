import { useCallback, useEffect, useState } from 'react';
import {
  PanelCard,
  RefreshButton,
  StatusBadge,
} from '../components/UiPrimitives';
import {
  buildFlagPatchDiff,
  callAdminAction,
  validateSemverOrEmpty,
} from '../lib/adminClient';
import type { AiTaskKey, FeatureFlags } from '../lib/types';

const TASK_TOGGLES: Array<{ key: keyof FeatureFlags; label: string; desc: string }> = [
  { key: 'aiEnabled', label: 'Master AI Switch (aiEnabled)', desc: 'Global gate across all AI tasks.' },
  { key: 'aiChatEnabled', label: 'AI Nutrition Chat', desc: 'Interactive Food Insight Coach & product chat.' },
  { key: 'aiMealPlannerEnabled', label: 'AI Meal Planner (v2)', desc: 'Personalized 4-meal daily planner.' },
  { key: 'mealPlannerEnabled', label: 'Legacy Meal Planner Flag', desc: 'Kept in sync with aiMealPlannerEnabled for older clients.' },
  { key: 'aiProductAnalysisEnabled', label: 'AI Product Analysis', desc: 'Narrative explanation card on Product Details.' },
  { key: 'aiMealParserEnabled', label: 'AI Meal Text Parser', desc: 'Natural-language meal logging macro estimator.' },
  { key: 'aiRecalibrationEnabled', label: 'AI Macro Recalibration', desc: 'Safe ±10% daily target adjustments.' },
  { key: 'aiQuickRepliesEnabled', label: 'AI Quick Replies', desc: 'Suggested follow-up chips inside chat.' },
  { key: 'additiveInsightsEnabled', label: 'Food Additives Card', desc: 'INS/E code glossary card with live overrides.' },
  { key: 'alternativesEnabled', label: 'Verified Alternatives', desc: 'Healthy comparison cards on Product Details.' },
];

const QUOTA_TASKS: Array<{ key: AiTaskKey; label: string; fallback: number }> = [
  { key: 'chat', label: 'Chat', fallback: 40 },
  { key: 'meal', label: 'Meal Parser', fallback: 25 },
  { key: 'plan', label: 'Meal Plan', fallback: 8 },
  { key: 'analysis', label: 'Product Analysis', fallback: 35 },
  { key: 'macros', label: 'Macro Recalibration', fallback: 8 },
  { key: 'quickReplies', label: 'Quick Replies', fallback: 40 },
];

export function FlagsConfigPage({
  onNotify,
}: {
  onNotify: (type: 'success' | 'error', message: string) => void;
}) {
  const [baseline, setBaseline] = useState<FeatureFlags>({});
  const [draft, setDraft] = useState<FeatureFlags>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await callAdminAction<{ flags: FeatureFlags }>('getConfig');
      setBaseline(res.flags ?? {});
      setDraft(res.flags ?? {});
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to load configuration.');
    } finally {
      setLoading(false);
    }
  }, [onNotify]);

  useEffect(() => {
    void load();
  }, [load]);

  const diff = buildFlagPatchDiff(baseline, draft);
  const hasChanges = Object.keys(diff).length > 0;
  const semverValid = validateSemverOrEmpty(draft.minAppVersion ?? '');

  const save = async () => {
    if (!hasChanges || !semverValid) return;
    setSaving(true);
    try {
      const res = await callAdminAction<{ flags: FeatureFlags }>('updateConfig', { patch: diff });
      setBaseline(res.flags ?? {});
      setDraft(res.flags ?? {});
      onNotify('success', `Saved ${Object.keys(diff).length} configuration update(s).`);
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to save configuration.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900">
            Feature Flags, Quotas & Release Gate
          </h1>
          <p className="text-sm text-slate-500">
            All changes are allowlist-validated server-side and recorded in the audit log.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <RefreshButton loading={loading} onClick={() => void load()} />
          <button
            type="button"
            disabled={!hasChanges || !semverValid || saving}
            onClick={() => void save()}
            className="rounded-xl bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-45"
          >
            {saving ? 'Saving…' : `Publish Changes (${Object.keys(diff).length})`}
          </button>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <PanelCard title="Feature Switches" subtitle="Immediate live effect on app startup & next screen build">
          <div className="divide-y divide-slate-100">
            {TASK_TOGGLES.map((item) => {
              const checked = draft[item.key] === true;
              return (
                <label
                  key={item.key}
                  className="flex cursor-pointer items-center justify-between gap-4 py-3 first:pt-0 last:pb-0"
                >
                  <div>
                    <div className="text-sm font-medium text-slate-900">{item.label}</div>
                    <div className="text-xs text-slate-500">{item.desc}</div>
                  </div>
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={(e) => {
                      const val = e.target.checked;
                      setDraft((prev) => {
                        const next = { ...prev, [item.key]: val };
                        if (item.key === 'aiMealPlannerEnabled') next.mealPlannerEnabled = val;
                        if (item.key === 'mealPlannerEnabled') next.aiMealPlannerEnabled = val;
                        return next;
                      });
                    }}
                    className="h-4 w-4 accent-emerald-600"
                  />
                </label>
              );
            })}
          </div>
        </PanelCard>

        <div className="space-y-6">
          <PanelCard title="Maintenance & App Version Gate" subtitle="Protect mobile users during incidents or forced upgrades">
            <div className="space-y-4">
              <label className="flex cursor-pointer items-center justify-between rounded-xl border border-slate-200 p-3">
                <div>
                  <div className="text-sm font-semibold text-slate-900">
                    Maintenance Mode
                  </div>
                  <div className="text-xs text-slate-500">
                    Blocks app entry and displays message below.
                  </div>
                </div>
                <input
                  type="checkbox"
                  checked={draft.maintenanceMode === true}
                  onChange={(e) =>
                    setDraft((p) => ({ ...p, maintenanceMode: e.target.checked }))
                  }
                  className="h-4 w-4 accent-rose-600"
                />
              </label>

              <div>
                <label className="block text-xs font-semibold text-slate-700">
                  Maintenance Message
                </label>
                <textarea
                  rows={2}
                  maxLength={300}
                  value={draft.maintenanceMessage ?? ''}
                  onChange={(e) =>
                    setDraft((p) => ({ ...p, maintenanceMessage: e.target.value }))
                  }
                  placeholder="Scheduled database upgrade in progress..."
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700">
                  Minimum Supported App Version (`x.y.z` or blank)
                </label>
                <input
                  type="text"
                  value={draft.minAppVersion ?? ''}
                  onChange={(e) =>
                    setDraft((p) => ({ ...p, minAppVersion: e.target.value }))
                  }
                  placeholder="1.0.2"
                  className={`mt-1 w-full rounded-xl border px-3 py-2 text-sm ${
                    semverValid ? 'border-slate-300' : 'border-rose-400 bg-rose-50'
                  }`}
                />
                {!semverValid ? (
                  <p className="mt-1 text-xs text-rose-600">
                    Use semantic format like 1.0.2 or leave blank.
                  </p>
                ) : null}
              </div>
            </div>
          </PanelCard>

          <PanelCard title="Daily Quotas, Rate Limits & Legal Consent" subtitle="Server-side cost & compliance guardrails">
            <div className="grid gap-3 sm:grid-cols-2">
              {QUOTA_TASKS.map((t) => (
                <div key={t.key}>
                  <label className="block text-xs font-medium text-slate-700">
                    {t.label} / day
                  </label>
                  <input
                    type="number"
                    min={0}
                    max={500}
                    value={draft.aiDailyLimits?.[t.key] ?? t.fallback}
                    onChange={(e) =>
                      setDraft((p) => ({
                        ...p,
                        aiDailyLimits: {
                          ...p.aiDailyLimits,
                          [t.key]: Number(e.target.value),
                        },
                      }))
                    }
                    className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-1.5 text-sm tabular-nums"
                  />
                </div>
              ))}
              <div>
                <label className="block text-xs font-medium text-slate-700">
                  IP Burst Limit / min
                </label>
                <input
                  type="number"
                  min={1}
                  max={500}
                  value={draft.aiIpPerMinuteLimit ?? 30}
                  onChange={(e) =>
                    setDraft((p) => ({
                      ...p,
                      aiIpPerMinuteLimit: Number(e.target.value),
                    }))
                  }
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-1.5 text-sm tabular-nums"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-700">
                  Macro Drift Cap (0–10%)
                </label>
                <input
                  type="number"
                  min={0}
                  max={10}
                  step={0.5}
                  value={draft.macroMaxAdjustmentPercent ?? 10}
                  onChange={(e) =>
                    setDraft((p) => ({
                      ...p,
                      macroMaxAdjustmentPercent: Number(e.target.value),
                    }))
                  }
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-1.5 text-sm tabular-nums"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-700">
                  Required Terms Version
                </label>
                <input
                  type="text"
                  value={draft.requiredTermsVersion ?? ''}
                  onChange={(e) =>
                    setDraft((p) => ({ ...p, requiredTermsVersion: e.target.value }))
                  }
                  placeholder="2026-11-25"
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-1.5 text-sm"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-700">
                  Required Privacy Version
                </label>
                <input
                  type="text"
                  value={draft.requiredPrivacyVersion ?? ''}
                  onChange={(e) =>
                    setDraft((p) => ({ ...p, requiredPrivacyVersion: e.target.value }))
                  }
                  placeholder="2026-11-25"
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-1.5 text-sm"
                />
              </div>
            </div>
            {hasChanges ? (
              <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs text-amber-900">
                <div className="mb-1 flex items-center gap-2 font-semibold">
                  <StatusBadge label="UNSAVED DIFF" tone="warn" />
                  Ready to publish
                </div>
                <pre className="overflow-x-auto text-[11px]">
                  {JSON.stringify(diff, null, 2)}
                </pre>
              </div>
            ) : null}
          </PanelCard>
        </div>
      </div>
    </div>
  );
}
