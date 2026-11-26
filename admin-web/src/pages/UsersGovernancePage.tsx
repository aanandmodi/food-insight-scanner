import { useCallback, useEffect, useState } from 'react';
import {
  ConfirmTextModal,
  PanelCard,
  RefreshButton,
  StatusBadge,
  formatIso,
} from '../components/UiPrimitives';
import { callAdminAction } from '../lib/adminClient';
import type {
  AuditLogEntry,
  DeletionRequest,
  UserLookupResult,
} from '../lib/types';

export function UsersGovernancePage({
  onNotify,
}: {
  onNotify: (type: 'success' | 'error', message: string) => void;
}) {
  const [query, setQuery] = useState('');
  const [lookedUp, setLookedUp] = useState<UserLookupResult | null>(null);
  const [suspendReason, setSuspendReason] = useState('');
  const [deletions, setDeletions] = useState<DeletionRequest[]>([]);
  const [audits, setAudits] = useState<AuditLogEntry[]>([]);
  const [reqEmail, setReqEmail] = useState('');
  const [reqNotes, setReqNotes] = useState('');
  const [loading, setLoading] = useState(true);
  const [deleteTarget, setDeleteTarget] = useState<{
    uid: string;
    deletionRequestId?: string;
  } | null>(null);
  const [busyDelete, setBusyDelete] = useState(false);

  const loadQueues = useCallback(async () => {
    setLoading(true);
    try {
      const [delRes, audRes] = await Promise.all([
        callAdminAction<{ requests: DeletionRequest[] }>('listDeletionRequests'),
        callAdminAction<{ logs: AuditLogEntry[] }>('listAuditLogs'),
      ]);
      setDeletions(delRes.requests ?? []);
      setAudits(audRes.logs ?? []);
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to load governance queues.');
    } finally {
      setLoading(false);
    }
  }, [onNotify]);

  useEffect(() => {
    void loadQueues();
  }, [loadQueues]);

  const lookup = async () => {
    const clean = query.trim();
    if (!clean) return;
    try {
      const res = await callAdminAction<UserLookupResult>(
        'lookupUser',
        clean.includes('@') ? { email: clean } : { uid: clean },
      );
      setLookedUp(res);
    } catch (err) {
      setLookedUp(null);
      onNotify('error', err instanceof Error ? err.message : 'User not found.');
    }
  };

  const toggleSuspension = async (uid: string, suspend: boolean) => {
    try {
      await callAdminAction('toggleUserSuspension', {
        userId: uid,
        suspend,
        reason: suspendReason.trim(),
      });
      onNotify('success', suspend ? `Suspended ${uid}.` : `Restored ${uid}.`);
      setSuspendReason('');
      const refreshed = await callAdminAction<UserLookupResult>('lookupUser', { uid });
      setLookedUp(refreshed);
      await loadQueues();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Suspension update failed.');
    }
  };

  const executeDelete = async () => {
    if (!deleteTarget) return;
    setBusyDelete(true);
    try {
      await callAdminAction('deleteUserAccount', {
        userId: deleteTarget.uid,
        confirmUid: deleteTarget.uid,
        deletionRequestId: deleteTarget.deletionRequestId,
      });
      onNotify('success', `Permanently purged account ${deleteTarget.uid}.`);
      if (lookedUp?.uid === deleteTarget.uid) setLookedUp(null);
      setDeleteTarget(null);
      await loadQueues();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Account purge failed.');
    } finally {
      setBusyDelete(false);
    }
  };

  const addDeletionRequest = async () => {
    if (!reqEmail.trim()) return;
    try {
      await callAdminAction('createDeletionRequest', {
        requestEmail: reqEmail.trim(),
        notes: reqNotes.trim(),
        source: 'web_email',
      });
      onNotify('success', 'Logged deletion request.');
      setReqEmail('');
      setReqNotes('');
      await loadQueues();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Could not log deletion request.');
    }
  };

  const resolveDeletion = async (id: string, status: 'completed' | 'rejected') => {
    try {
      await callAdminAction('resolveDeletionRequest', {
        id,
        status,
        resolutionNote: `Marked ${status} in Admin Portal`,
      });
      onNotify('success', `Marked deletion request ${status}.`);
      await loadQueues();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to update deletion request.');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900">
            Users, Deletions & Immutable Audit Log
          </h1>
          <p className="text-sm text-slate-500">
            Lookup user accounts, enforce instant suspensions, process web deletion requests, and audit admin actions.
          </p>
        </div>
        <RefreshButton loading={loading} onClick={() => void loadQueues()} />
      </div>

      <PanelCard title="User Lookup & Account Actions">
        <div className="flex flex-wrap gap-2">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search by Firebase UID or email address"
            className="min-w-64 flex-1 rounded-xl border border-slate-300 px-3 py-2 text-sm"
          />
          <button
            type="button"
            onClick={() => void lookup()}
            className="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold text-white hover:bg-slate-800"
          >
            Lookup User
          </button>
        </div>

        {lookedUp ? (
          <div className="mt-5 grid gap-4 rounded-2xl border border-slate-200 bg-slate-50/70 p-4 lg:grid-cols-2">
            <div className="space-y-2 text-xs">
              <div className="flex flex-wrap items-center gap-2">
                <span className="font-mono text-sm font-bold text-slate-900">
                  {lookedUp.uid}
                </span>
                <StatusBadge
                  label={lookedUp.suspended ? 'SUSPENDED' : 'ACTIVE'}
                  tone={lookedUp.suspended ? 'danger' : 'good'}
                />
                {lookedUp.authUser?.emailVerified ? (
                  <StatusBadge label="email verified" tone="info" />
                ) : (
                  <StatusBadge label="email unverified" tone="warn" />
                )}
              </div>
              <div className="text-slate-600">
                Email: <strong>{lookedUp.authUser?.email ?? 'None / Anonymous'}</strong> · Providers:{' '}
                {lookedUp.authUser?.providers.join(', ') || 'anonymous'}
              </div>
              <div className="text-slate-500">
                Consents: {lookedUp.consents.length} · Abuse events: {lookedUp.abuseEvents.length} · Quotas rows:{' '}
                {lookedUp.quotas.length}
              </div>
            </div>

            <div className="flex flex-col justify-between gap-2.5">
              <input
                type="text"
                placeholder="Suspension reason (saved to audit log)"
                value={suspendReason}
                onChange={(e) => setSuspendReason(e.target.value)}
                className="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-xs"
              />
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => void toggleSuspension(lookedUp.uid, !lookedUp.suspended)}
                  className={`rounded-xl px-3.5 py-2 text-xs font-semibold text-white ${
                    lookedUp.suspended
                      ? 'bg-emerald-600 hover:bg-emerald-700'
                      : 'bg-amber-600 hover:bg-amber-700'
                  }`}
                >
                  {lookedUp.suspended ? 'Unsuspend Account' : 'Suspend & Revoke Sessions'}
                </button>
                <button
                  type="button"
                  onClick={() => setDeleteTarget({ uid: lookedUp.uid })}
                  className="rounded-xl bg-rose-600 px-3.5 py-2 text-xs font-semibold text-white hover:bg-rose-700"
                >
                  Permanent Account Purge
                </button>
              </div>
            </div>
          </div>
        ) : null}
      </PanelCard>

      <PanelCard
        title="Web & Play Store Account Deletion Queue"
        subtitle="Track requests submitted to delete-account support email and run full cross-DB purge"
      >
        <div className="mb-4 flex flex-wrap gap-2">
          <input
            type="text"
            placeholder="User email or UID"
            value={reqEmail}
            onChange={(e) => setReqEmail(e.target.value)}
            className="min-w-52 flex-1 rounded-xl border border-slate-300 px-3 py-2 text-xs"
          />
          <input
            type="text"
            placeholder="Verification notes (optional)"
            value={reqNotes}
            onChange={(e) => setReqNotes(e.target.value)}
            className="min-w-52 flex-1 rounded-xl border border-slate-300 px-3 py-2 text-xs"
          />
          <button
            type="button"
            onClick={() => void addDeletionRequest()}
            className="rounded-xl bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-700"
          >
            Log Request
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr>
                <th className="py-2 pr-3">Email / Target UID</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3">Notes</th>
                <th className="py-2 pr-3">Created</th>
                <th className="py-2 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {deletions.map((d) => (
                <tr key={d.id}>
                  <td className="py-2 pr-3">
                    <div className="font-semibold text-slate-900">
                      {d.request_email || '—'}
                    </div>
                    <div className="font-mono text-[11px] text-slate-500">
                      {d.target_uid || 'UID unresolved'}
                    </div>
                  </td>
                  <td className="py-2 pr-3">
                    <StatusBadge
                      label={d.status}
                      tone={
                        d.status === 'pending'
                          ? 'warn'
                          : d.status === 'completed'
                            ? 'good'
                            : 'neutral'
                      }
                    />
                  </td>
                  <td className="py-2 pr-3 text-slate-600">{d.notes || '—'}</td>
                  <td className="py-2 pr-3 text-slate-500">{formatIso(d.created_at)}</td>
                  <td className="py-2 text-right space-x-2">
                    {d.status === 'pending' && d.target_uid ? (
                      <button
                        type="button"
                        onClick={() =>
                          setDeleteTarget({ uid: d.target_uid, deletionRequestId: d.id })
                        }
                        className="rounded-lg bg-rose-600 px-2.5 py-1 text-[11px] font-semibold text-white"
                      >
                        Purge
                      </button>
                    ) : null}
                    {d.status === 'pending' ? (
                      <button
                        type="button"
                        onClick={() => void resolveDeletion(d.id, 'rejected')}
                        className="rounded-lg border border-slate-200 px-2.5 py-1 text-[11px] font-semibold"
                      >
                        Reject
                      </button>
                    ) : null}
                  </td>
                </tr>
              ))}
              {!deletions.length ? (
                <tr>
                  <td colSpan={5} className="py-4 text-center text-slate-500">
                    No deletion requests logged yet.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </PanelCard>

      <PanelCard title="Immutable Admin Audit Log (Latest 100)">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr>
                <th className="py-2 pr-3">Timestamp</th>
                <th className="py-2 pr-3">Actor</th>
                <th className="py-2 pr-3">Action</th>
                <th className="py-2 pr-3">Target</th>
                <th className="py-2">Details</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {audits.map((log) => (
                <tr key={log.id}>
                  <td className="py-2 pr-3 whitespace-nowrap text-slate-500">
                    {formatIso(log.created_at)}
                  </td>
                  <td className="py-2 pr-3 text-slate-800">
                    {log.admin_email || log.admin_uid}
                  </td>
                  <td className="py-2 pr-3">
                    <StatusBadge label={log.action} tone="info" />
                  </td>
                  <td className="py-2 pr-3 font-mono text-[11px] text-slate-600">
                    {log.target_type}:{log.target_id}
                  </td>
                  <td className="max-w-xs truncate py-2 font-mono text-[11px] text-slate-500">
                    {JSON.stringify(log.details)}
                  </td>
                </tr>
              ))}
              {!audits.length ? (
                <tr>
                  <td colSpan={5} className="py-4 text-center text-slate-500">
                    Audit log will populate after your first admin action.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </PanelCard>

      <ConfirmTextModal
        open={Boolean(deleteTarget)}
        title="Confirm Permanent Account Deletion"
        description="This permanently erases all Firebase Auth credentials, Firestore profiles, Supabase scans/logs/consents/reports, and storage uploads. This cannot be undone."
        confirmToken={deleteTarget?.uid ?? ''}
        confirmLabel="Purge Account Forever"
        busy={busyDelete}
        onCancel={() => setDeleteTarget(null)}
        onConfirm={() => void executeDelete()}
      />
    </div>
  );
}
