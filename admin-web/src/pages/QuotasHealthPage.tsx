import { useCallback, useEffect, useState } from 'react';
import {
  PanelCard,
  RefreshButton,
  StatusBadge,
  formatIso,
} from '../components/UiPrimitives';
import { callAdminAction } from '../lib/adminClient';
import type {
  AbuseEvent,
  IpRateLimitRow,
  ProviderHealthRow,
  UserQuotaRow,
} from '../lib/types';

export function QuotasHealthPage({
  onNotify,
}: {
  onNotify: (type: 'success' | 'error', message: string) => void;
}) {
  const [health, setHealth] = useState<ProviderHealthRow[]>([]);
  const [quotas, setQuotas] = useState<UserQuotaRow[]>([]);
  const [ipLimits, setIpLimits] = useState<IpRateLimitRow[]>([]);
  const [abuse, setAbuse] = useState<AbuseEvent[]>([]);
  const [severityFilter, setSeverityFilter] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [qh, ab] = await Promise.all([
        callAdminAction<{
          health: ProviderHealthRow[];
          quotas: UserQuotaRow[];
          ipLimits: IpRateLimitRow[];
        }>('getQuotasAndHealth'),
        callAdminAction<{ events: AbuseEvent[] }>('listAbuseEvents', {
          ...(severityFilter ? { severity: severityFilter } : {}),
        }),
      ]);
      setHealth(qh.health ?? []);
      setQuotas(qh.quotas ?? []);
      setIpLimits(qh.ipLimits ?? []);
      setAbuse(ab.events ?? []);
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to load telemetry.');
    } finally {
      setLoading(false);
    }
  }, [onNotify, severityFilter]);

  useEffect(() => {
    void load();
  }, [load]);

  const resetCircuit = async (provider: string) => {
    try {
      await callAdminAction('resetProviderCircuit', { provider });
      onNotify('success', `Reset circuit breaker for ${provider.toUpperCase()}.`);
      await load();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to reset circuit.');
    }
  };

  const resetQuota = async (userId: string, task?: string) => {
    try {
      await callAdminAction('resetUserQuota', { userId, task });
      onNotify('success', `Cleared quota for ${userId}${task ? ` (${task})` : ''}.`);
      await load();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to reset quota.');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900">
            Quotas, Provider Health & Abuse Telemetry
          </h1>
          <p className="text-sm text-slate-500">
            Inspect circuit breakers, daily AI consumption, IP rate-limit windows, and prompt-shield blocks.
          </p>
        </div>
        <RefreshButton loading={loading} onClick={() => void load()} />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <PanelCard title="AI Provider Circuits">
          <div className="space-y-3">
            {health.map((row) => {
              const cooled =
                Boolean(row.cooldown_until) &&
                new Date(row.cooldown_until!).getTime() > Date.now();
              return (
                <div
                  key={row.provider}
                  className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 p-3.5"
                >
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-semibold uppercase text-slate-900">
                        {row.provider}
                      </span>
                      <StatusBadge
                        label={cooled ? 'OPEN / COOLDOWN' : 'HEALTHY'}
                        tone={cooled ? 'danger' : 'good'}
                      />
                    </div>
                    <p className="mt-1 text-xs text-slate-500">
                      Failures: {row.consecutive_failures} · Last HTTP: {row.last_status ?? '—'} ·{' '}
                      Updated: {formatIso(row.updated_at)}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => void resetCircuit(row.provider)}
                    className="rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-50"
                  >
                    Reset Circuit
                  </button>
                </div>
              );
            })}
            {!health.length ? (
              <p className="text-sm text-slate-500">No circuit records yet.</p>
            ) : null}
          </div>
        </PanelCard>

        <PanelCard title="Recent IP Rate-Limit Buckets (Hashed)">
          {!ipLimits.length ? (
            <p className="text-sm text-slate-500">No IP buckets recorded yet.</p>
          ) : (
            <div className="max-h-64 overflow-y-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-200 text-slate-500">
                  <tr>
                    <th className="py-2 pr-3">IP Digest</th>
                    <th className="py-2 pr-3">Window</th>
                    <th className="py-2 text-right">Requests</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {ipLimits.map((row) => (
                    <tr key={`${row.ip_hash}-${row.window_start}`}>
                      <td className="py-2 pr-3 font-mono text-[11px] text-slate-700">
                        {row.ip_hash.slice(0, 14)}…
                      </td>
                      <td className="py-2 pr-3 text-slate-500">
                        {formatIso(row.window_start)}
                      </td>
                      <td className="py-2 text-right font-semibold tabular-nums">
                        {row.request_count}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </PanelCard>
      </div>

      <PanelCard title="Per-User Daily AI Quotas (Top 50)">
        {!quotas.length ? (
          <p className="text-sm text-slate-500">No quota usage recorded yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-200 text-slate-500">
                <tr>
                  <th className="py-2 pr-3">User UID</th>
                  <th className="py-2 pr-3">Task</th>
                  <th className="py-2 pr-3">Date</th>
                  <th className="py-2 pr-3 text-right">Count</th>
                  <th className="py-2 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {quotas.map((q) => (
                  <tr key={`${q.user_id}-${q.task}-${q.day_date}`}>
                    <td className="py-2 pr-3 font-mono text-[11px] text-slate-800">
                      {q.user_id}
                    </td>
                    <td className="py-2 pr-3">
                      <StatusBadge label={q.task} tone="info" />
                    </td>
                    <td className="py-2 pr-3 text-slate-500">{q.day_date}</td>
                    <td className="py-2 pr-3 text-right font-semibold tabular-nums">
                      {q.daily_count}
                    </td>
                    <td className="py-2 text-right">
                      <button
                        type="button"
                        onClick={() => void resetQuota(q.user_id, q.task)}
                        className="rounded-lg border border-slate-200 px-2.5 py-1 text-[11px] font-semibold text-slate-700 hover:bg-slate-50"
                      >
                        Reset
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </PanelCard>

      <PanelCard
        title="Security & Prompt-Shield Abuse Telemetry"
        subtitle="Non-PII redacted triggers from promptShield and outputSafety"
        actions={
          <select
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value)}
            className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-700"
          >
            <option value="">All severities</option>
            <option value="high">High only</option>
            <option value="medium">Medium only</option>
            <option value="low">Low only</option>
          </select>
        }
      >
        {!abuse.length ? (
          <p className="text-sm text-slate-500">No abuse events matching filter.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-200 text-slate-500">
                <tr>
                  <th className="py-2 pr-3">Time</th>
                  <th className="py-2 pr-3">Severity</th>
                  <th className="py-2 pr-3">User UID</th>
                  <th className="py-2 pr-3">Task / Rule</th>
                  <th className="py-2">Redacted Snippet</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {abuse.map((ev) => (
                  <tr key={ev.id}>
                    <td className="py-2 pr-3 whitespace-nowrap text-slate-500">
                      {formatIso(ev.created_at)}
                    </td>
                    <td className="py-2 pr-3">
                      <StatusBadge
                        label={ev.severity}
                        tone={
                          ev.severity === 'high'
                            ? 'danger'
                            : ev.severity === 'medium'
                              ? 'warn'
                              : 'neutral'
                        }
                      />
                    </td>
                    <td className="py-2 pr-3 font-mono text-[11px]">{ev.user_id}</td>
                    <td className="py-2 pr-3">
                      <div className="font-medium text-slate-800">{ev.category}</div>
                      <div className="text-[11px] text-slate-500">
                        {ev.task} · {ev.rule_id}
                      </div>
                    </td>
                    <td className="max-w-xs truncate py-2 text-slate-600">
                      {ev.snippet || '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </PanelCard>
    </div>
  );
}
