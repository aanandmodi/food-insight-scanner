import { useCallback, useEffect, useState } from 'react';
import { ShieldAlert, Sparkles, Wrench } from 'lucide-react';
import {
  PanelCard,
  RefreshButton,
  StatTile,
  StatusBadge,
  formatIso,
} from '../components/UiPrimitives';
import { callAdminAction } from '../lib/adminClient';
import type { FeatureFlags, OverviewResponse } from '../lib/types';

export function OverviewPage({
  onNotify,
  onNavigate,
}: {
  onNotify: (type: 'success' | 'error', message: string) => void;
  onNavigate: (tab: 'flags' | 'quotas' | 'catalog' | 'users') => void;
}) {
  const [data, setData] = useState<OverviewResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [savingKey, setSavingKey] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await callAdminAction<OverviewResponse>('overview');
      setData(res);
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to load overview.');
    } finally {
      setLoading(false);
    }
  }, [onNotify]);

  useEffect(() => {
    void load();
  }, [load]);

  const toggleFlag = async (key: keyof FeatureFlags, nextValue: boolean) => {
    setSavingKey(String(key));
    try {
      const res = await callAdminAction<{ flags: FeatureFlags }>('updateConfig', {
        patch: { [key]: nextValue },
      });
      setData((prev) => (prev ? { ...prev, flags: res.flags } : prev));
      onNotify('success', `Updated ${String(key)} -> ${String(nextValue)}.`);
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to update switch.');
    } finally {
      setSavingKey(null);
    }
  };

  const flags = data?.flags ?? {};
  const metrics = data?.metrics;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900">
            Operations Overview
          </h1>
          <p className="text-sm text-slate-500">
            Live backend telemetry, provider circuits, and instant release controls.
          </p>
        </div>
        <RefreshButton loading={loading} onClick={() => void load()} />
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile
          label="AI Requests Today"
          value={metrics?.aiRequestsToday ?? '—'}
          hint={`${metrics?.activeQuotaUsersToday ?? 0} active users`}
          tone="good"
        />
        <StatTile
          label="Open Product Reports"
          value={metrics?.openReportsCount ?? '—'}
          hint="Click Catalog to verify barcodes"
          tone={(metrics?.openReportsCount ?? 0) > 0 ? 'warn' : 'neutral'}
        />
        <StatTile
          label="Pending Deletions"
          value={metrics?.pendingDeletionsCount ?? '—'}
          hint="Web & GDPR account wipes"
          tone={(metrics?.pendingDeletionsCount ?? 0) > 0 ? 'warn' : 'neutral'}
        />
        <StatTile
          label="Recent Abuse Triggers"
          value={metrics?.recentAbuseCount ?? '—'}
          hint="Sampled last 50 events"
          tone={(metrics?.recentAbuseCount ?? 0) > 10 ? 'danger' : 'neutral'}
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <PanelCard
          title="Instant Safety & Release Switches"
          subtitle="Writes directly to Firestore config/featureFlags and audit log"
          actions={
            <button
              type="button"
              onClick={() => onNavigate('flags')}
              className="text-xs font-semibold text-emerald-700 hover:underline"
            >
              All flags & quotas →
            </button>
          }
        >
          <div className="divide-y divide-slate-100">
            {(
              [
                {
                  key: 'aiEnabled' as const,
                  title: 'Master AI Switch (aiEnabled)',
                  desc: 'Disabling pauses all AI endpoints without touching deterministic allergy safety.',
                  icon: Sparkles,
                  dangerWhenOn: false,
                },
                {
                  key: 'maintenanceMode' as const,
                  title: 'Maintenance Mode',
                  desc: 'Displays a maintenance notice screen to signed-in mobile clients.',
                  icon: Wrench,
                  dangerWhenOn: true,
                },
                {
                  key: 'alternativesEnabled' as const,
                  title: 'Verified Alternatives',
                  desc: 'Shows healthier verified alternatives on Product Details.',
                  icon: ShieldAlert,
                  dangerWhenOn: false,
                },
              ] as const
            ).map((item) => {
              const Icon = item.icon;
              const current = flags[item.key] === true;
              const busy = savingKey === item.key;
              return (
                <div
                  key={item.key}
                  className="flex items-center justify-between gap-4 py-3.5 first:pt-0 last:pb-0"
                >
                  <div className="flex items-start gap-3">
                    <div className="rounded-xl bg-slate-100 p-2 text-slate-700">
                      <Icon className="h-4 w-4" />
                    </div>
                    <div>
                      <div className="text-sm font-semibold text-slate-900">
                        {item.title}
                      </div>
                      <p className="text-xs text-slate-500">{item.desc}</p>
                    </div>
                  </div>
                  <button
                    type="button"
                    disabled={busy || loading}
                    onClick={() => void toggleFlag(item.key, !current)}
                    className={`shrink-0 rounded-xl px-3.5 py-1.5 text-xs font-semibold transition disabled:opacity-50 ${
                      current
                        ? item.dangerWhenOn
                          ? 'bg-rose-600 text-white hover:bg-rose-700'
                          : 'bg-emerald-600 text-white hover:bg-emerald-700'
                        : 'border border-slate-300 bg-white text-slate-700 hover:bg-slate-50'
                    }`}
                  >
                    {busy ? 'Saving…' : current ? 'ON' : 'OFF'}
                  </button>
                </div>
              );
            })}
          </div>
          <div className="mt-4 flex flex-wrap items-center justify-between gap-2 rounded-xl bg-slate-50 px-3.5 py-2.5 text-xs text-slate-600">
            <span>
              Min app version: <strong>{flags.minAppVersion || 'None'}</strong>
            </span>
            <span>
              Legal versions: T=<strong>{flags.requiredTermsVersion || 'default'}</strong> · P=
              <strong>{flags.requiredPrivacyVersion || 'default'}</strong>
            </span>
          </div>
        </PanelCard>

        <PanelCard
          title="AI Provider Circuit Health"
          subtitle="Shared Edge & PostgreSQL cooldown state"
          actions={
            <button
              type="button"
              onClick={() => onNavigate('quotas')}
              className="text-xs font-semibold text-emerald-700 hover:underline"
            >
              Quotas & abuse log →
            </button>
          }
        >
          {!data?.providerHealth.length ? (
            <p className="text-sm text-slate-500">
              No provider health rows recorded yet.
            </p>
          ) : (
            <div className="space-y-3">
              {data.providerHealth.map((row) => {
                const cooled =
                  Boolean(row.cooldown_until) &&
                  new Date(row.cooldown_until!).getTime() > Date.now();
                return (
                  <div
                    key={row.provider}
                    className="flex items-center justify-between rounded-xl border border-slate-200 p-3.5"
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold uppercase text-slate-900">
                          {row.provider}
                        </span>
                        <StatusBadge
                          label={cooled ? 'CIRCUIT OPEN' : 'HEALTHY'}
                          tone={cooled ? 'danger' : 'good'}
                        />
                      </div>
                      <div className="mt-1 text-xs text-slate-500">
                        Consecutive failures: {row.consecutive_failures}
                        {row.cooldown_until
                          ? ` · Cooldown until ${formatIso(row.cooldown_until)}`
                          : ''}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </PanelCard>
      </div>
    </div>
  );
}
