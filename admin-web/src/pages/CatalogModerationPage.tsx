import { useCallback, useEffect, useState } from 'react';
import {
  PanelCard,
  RefreshButton,
  StatusBadge,
  formatIso,
} from '../components/UiPrimitives';
import { callAdminAction, splitCsvTags } from '../lib/adminClient';
import type {
  AdditiveOverride,
  CanonicalProduct,
  ProductReport,
} from '../lib/types';

export function CatalogModerationPage({
  onNotify,
}: {
  onNotify: (type: 'success' | 'error', message: string) => void;
}) {
  const [reports, setReports] = useState<ProductReport[]>([]);
  const [statusFilter, setStatusFilter] = useState('open');
  const [additives, setAdditives] = useState<AdditiveOverride[]>([]);
  const [loading, setLoading] = useState(true);

  const [barcode, setBarcode] = useState('');
  const [activeReportId, setActiveReportId] = useState('');
  const [productDraft, setProductDraft] = useState<CanonicalProduct | null>(null);
  const [allergensCsv, setAllergensCsv] = useState('');
  const [tracesCsv, setTracesCsv] = useState('');
  const [savingProduct, setSavingProduct] = useState(false);

  const [addIns, setAddIns] = useState('');
  const [addName, setAddName] = useState('');
  const [addCategory, setAddCategory] = useState('Additive');
  const [addTier, setAddTier] = useState<'low' | 'caution' | 'avoid' | 'info'>('caution');
  const [addSummary, setAddSummary] = useState('');
  const [addNotes, setAddNotes] = useState('');
  const [addActive, setAddActive] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [repRes, addRes] = await Promise.all([
        callAdminAction<{ reports: ProductReport[] }>('listProductReports', {
          status: statusFilter,
        }),
        callAdminAction<{ additives: AdditiveOverride[] }>('listAdditiveOverrides'),
      ]);
      setReports(repRes.reports ?? []);
      setAdditives(addRes.additives ?? []);
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to load catalog data.');
    } finally {
      setLoading(false);
    }
  }, [onNotify, statusFilter]);

  useEffect(() => {
    void load();
  }, [load]);

  const loadBarcode = async (targetBarcode: string, reportId = '', fallbackName = '') => {
    const clean = targetBarcode.trim();
    if (!/^\d{8,14}$/.test(clean)) {
      onNotify('error', 'Enter an 8–14 digit barcode.');
      return;
    }
    setBarcode(clean);
    setActiveReportId(reportId);
    try {
      const res = await callAdminAction<{ product: CanonicalProduct | null }>(
        'getCanonicalProduct',
        { barcode: clean },
      );
      const prod: CanonicalProduct = res.product ?? {
        barcode: clean,
        name: fallbackName || '',
        brand: '',
        category: '',
        ingredientsText: '',
        nutriscore: '',
        nutrition: {},
      };
      setProductDraft(prod);
      setAllergensCsv((prod.allergens ?? []).join(', '));
      setTracesCsv((prod.traces ?? []).join(', '));
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to load product.');
    }
  };

  const saveProduct = async () => {
    if (!productDraft) return;
    setSavingProduct(true);
    try {
      await callAdminAction('saveCanonicalProduct', {
        barcode: productDraft.barcode,
        resolveReportId: activeReportId || undefined,
        product: {
          ...productDraft,
          allergens: splitCsvTags(allergensCsv),
          traces: splitCsvTags(tracesCsv),
        },
      });
      onNotify(
        'success',
        `Saved verified canonical product ${productDraft.barcode}${activeReportId ? ' & resolved report' : ''}.`,
      );
      setActiveReportId('');
      await load();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to save product.');
    } finally {
      setSavingProduct(false);
    }
  };

  const resolveReport = async (id: string, status: 'resolved' | 'dismissed') => {
    try {
      await callAdminAction('resolveProductReport', {
        id,
        status,
        resolutionNote: status === 'dismissed' ? 'Dismissed in admin triage' : 'Resolved in admin triage',
      });
      onNotify('success', `Marked report ${status}.`);
      await load();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to update report.');
    }
  };

  const saveAdditive = async () => {
    try {
      await callAdminAction('upsertAdditiveOverride', {
        ins: addIns,
        name: addName,
        category: addCategory,
        safetyTier: addTier,
        summary: addSummary,
        dietaryNotes: addNotes,
        active: addActive,
      });
      onNotify('success', `Saved INS ${addIns.toUpperCase()} override.`);
      setAddIns('');
      setAddName('');
      setAddSummary('');
      setAddNotes('');
      await load();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to save additive.');
    }
  };

  const removeAdditive = async (ins: string) => {
    try {
      await callAdminAction('deleteAdditiveOverride', { ins });
      onNotify('success', `Removed INS ${ins.toUpperCase()} override.`);
      await load();
    } catch (err) {
      onNotify('error', err instanceof Error ? err.message : 'Failed to delete additive.');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900">
            Product Moderation & Additive Glossary
          </h1>
          <p className="text-sm text-slate-500">
            Triage inaccurate label reports, verify canonical Firestore barcodes, and publish live INS overrides.
          </p>
        </div>
        <RefreshButton loading={loading} onClick={() => void load()} />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <PanelCard
          title="Inaccurate Product Reports"
          actions={
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="rounded-xl border border-slate-200 px-3 py-1.5 text-xs font-medium"
            >
              <option value="open">Open</option>
              <option value="resolved">Resolved</option>
              <option value="dismissed">Dismissed</option>
              <option value="">All</option>
            </select>
          }
        >
          {!reports.length ? (
            <p className="text-sm text-slate-500">No reports in this queue.</p>
          ) : (
            <div className="space-y-3">
              {reports.map((rep) => (
                <div
                  key={rep.id}
                  className="rounded-xl border border-slate-200 p-3.5"
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div>
                      <span className="font-semibold text-slate-900">
                        {rep.product_name || 'Unnamed Product'}
                      </span>{' '}
                      <code className="rounded bg-slate-100 px-1.5 py-0.5 text-xs">
                        {rep.barcode}
                      </code>
                    </div>
                    <StatusBadge
                      label={rep.issue_type}
                      tone={rep.status === 'open' ? 'warn' : 'good'}
                    />
                  </div>
                  <p className="mt-1.5 text-xs text-slate-600">
                    {rep.notes || 'No user notes supplied.'}
                  </p>
                  <div className="mt-2.5 flex flex-wrap items-center justify-between gap-2 text-[11px] text-slate-400">
                    <span>
                      User {rep.user_id.slice(0, 10)}… · {formatIso(rep.created_at)}
                    </span>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() =>
                          void loadBarcode(rep.barcode, rep.id, rep.product_name)
                        }
                        className="rounded-lg bg-emerald-50 px-2.5 py-1 font-semibold text-emerald-700 hover:bg-emerald-100"
                      >
                        Inspect & Fix
                      </button>
                      {rep.status === 'open' ? (
                        <button
                          type="button"
                          onClick={() => void resolveReport(rep.id, 'dismissed')}
                          className="rounded-lg border border-slate-200 px-2.5 py-1 font-semibold text-slate-600 hover:bg-slate-50"
                        >
                          Dismiss
                        </button>
                      ) : null}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </PanelCard>

        <PanelCard
          title="Canonical Barcode Editor"
          subtitle="Edits authoritative Firestore products/{barcode} document"
        >
          <div className="mb-4 flex gap-2">
            <input
              type="text"
              value={barcode}
              onChange={(e) => setBarcode(e.target.value)}
              placeholder="Enter 8–14 digit barcode"
              className="flex-1 rounded-xl border border-slate-300 px-3 py-2 text-sm"
            />
            <button
              type="button"
              onClick={() => void loadBarcode(barcode)}
              className="rounded-xl bg-slate-900 px-4 py-2 text-xs font-semibold text-white hover:bg-slate-800"
            >
              Load
            </button>
          </div>

          {productDraft ? (
            <div className="space-y-3">
              {activeReportId ? (
                <div className="rounded-xl bg-emerald-50 px-3 py-2 text-xs font-medium text-emerald-800">
                  Saving will auto-resolve linked report #{activeReportId.slice(0, 8)}
                </div>
              ) : null}
              <div className="grid gap-3 sm:grid-cols-2">
                <input
                  type="text"
                  placeholder="Product Name *"
                  value={productDraft.name}
                  onChange={(e) =>
                    setProductDraft((p) => (p ? { ...p, name: e.target.value } : p))
                  }
                  className="rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
                <input
                  type="text"
                  placeholder="Brand"
                  value={productDraft.brand ?? ''}
                  onChange={(e) =>
                    setProductDraft((p) => (p ? { ...p, brand: e.target.value } : p))
                  }
                  className="rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
                <input
                  type="text"
                  placeholder="Category"
                  value={productDraft.category ?? ''}
                  onChange={(e) =>
                    setProductDraft((p) => (p ? { ...p, category: e.target.value } : p))
                  }
                  className="rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
                <input
                  type="text"
                  placeholder="Nutri-Score (a–e)"
                  maxLength={1}
                  value={productDraft.nutriscore ?? ''}
                  onChange={(e) =>
                    setProductDraft((p) => (p ? { ...p, nutriscore: e.target.value } : p))
                  }
                  className="rounded-xl border border-slate-300 px-3 py-2 text-sm uppercase"
                />
              </div>

              <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-4">
                {(
                  [
                    ['energyKcalPer100g', 'kcal / 100g'],
                    ['proteinGPer100g', 'Protein g'],
                    ['carbohydratesGPer100g', 'Carbs g'],
                    ['sugarGPer100g', 'Sugar g'],
                    ['fatGPer100g', 'Fat g'],
                    ['fiberGPer100g', 'Fiber g'],
                    ['sodiumMgPer100g', 'Sodium mg'],
                  ] as const
                ).map(([field, label]) => (
                  <div key={field}>
                    <label className="block text-[11px] font-medium text-slate-500">
                      {label}
                    </label>
                    <input
                      type="number"
                      step="0.1"
                      min="0"
                      value={productDraft.nutrition?.[field] ?? ''}
                      onChange={(e) => {
                        const val = e.target.value === '' ? null : Number(e.target.value);
                        setProductDraft((p) =>
                          p ? { ...p, nutrition: { ...p.nutrition, [field]: val } } : p,
                        );
                      }}
                      className="mt-0.5 w-full rounded-xl border border-slate-300 px-2.5 py-1.5 text-xs tabular-nums"
                    />
                  </div>
                ))}
              </div>

              <textarea
                rows={2}
                placeholder="Ingredients text (comma separated)"
                value={productDraft.ingredientsText ?? ''}
                onChange={(e) =>
                  setProductDraft((p) =>
                    p ? { ...p, ingredientsText: e.target.value } : p,
                  )
                }
                className="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
              />
              <div className="grid gap-3 sm:grid-cols-2">
                <input
                  type="text"
                  placeholder="Allergens (comma separated)"
                  value={allergensCsv}
                  onChange={(e) => setAllergensCsv(e.target.value)}
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs"
                />
                <input
                  type="text"
                  placeholder="Traces (comma separated)"
                  value={tracesCsv}
                  onChange={(e) => setTracesCsv(e.target.value)}
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs"
                />
              </div>
              <button
                type="button"
                disabled={savingProduct}
                onClick={() => void saveProduct()}
                className="w-full rounded-xl bg-emerald-600 py-2.5 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
              >
                {savingProduct ? 'Saving Canonical Record…' : 'Save & Mark Admin Verified'}
              </button>
            </div>
          ) : (
            <p className="text-sm text-slate-500">
              Load any barcode above or pick “Inspect & Fix” from a report.
            </p>
          )}
        </PanelCard>
      </div>

      <PanelCard
        title="Live Food Additive Overrides"
        subtitle="Supplements & overrides bundled assets/data/food_additives_v1.json in mobile app"
      >
        <div className="mb-5 grid gap-3 rounded-xl border border-slate-200 bg-slate-50/70 p-4 sm:grid-cols-6">
          <input
            type="text"
            placeholder="INS (e.g. 621)"
            value={addIns}
            onChange={(e) => setAddIns(e.target.value)}
            className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs"
          />
          <input
            type="text"
            placeholder="Additive Name"
            value={addName}
            onChange={(e) => setAddName(e.target.value)}
            className="sm:col-span-2 rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs"
          />
          <input
            type="text"
            placeholder="Category"
            value={addCategory}
            onChange={(e) => setAddCategory(e.target.value)}
            className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs"
          />
          <select
            value={addTier}
            onChange={(e) =>
              setAddTier(e.target.value as 'low' | 'caution' | 'avoid' | 'info')
            }
            className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs"
          >
            <option value="low">low</option>
            <option value="caution">caution</option>
            <option value="avoid">avoid</option>
            <option value="info">info</option>
          </select>
          <label className="flex items-center justify-center gap-2 text-xs font-medium">
            <input
              type="checkbox"
              checked={addActive}
              onChange={(e) => setAddActive(e.target.checked)}
              className="accent-emerald-600"
            />
            Active
          </label>
          <input
            type="text"
            placeholder="Short summary for users"
            value={addSummary}
            onChange={(e) => setAddSummary(e.target.value)}
            className="sm:col-span-3 rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs"
          />
          <input
            type="text"
            placeholder="Dietary notes (optional)"
            value={addNotes}
            onChange={(e) => setAddNotes(e.target.value)}
            className="sm:col-span-2 rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs"
          />
          <button
            type="button"
            onClick={() => void saveAdditive()}
            className="rounded-xl bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-700"
          >
            Save INS
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-200 text-slate-500">
              <tr>
                <th className="py-2 pr-3">INS</th>
                <th className="py-2 pr-3">Name & Summary</th>
                <th className="py-2 pr-3">Tier</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {additives.map((a) => (
                <tr key={a.ins}>
                  <td className="py-2.5 pr-3 font-mono font-semibold uppercase">
                    INS {a.ins}
                  </td>
                  <td className="py-2.5 pr-3">
                    <div className="font-semibold text-slate-900">
                      {a.name} · <span className="font-normal text-slate-500">{a.category}</span>
                    </div>
                    <div className="text-slate-600">{a.summary || '—'}</div>
                  </td>
                  <td className="py-2.5 pr-3">
                    <StatusBadge
                      label={a.safety_tier}
                      tone={
                        a.safety_tier === 'avoid'
                          ? 'danger'
                          : a.safety_tier === 'caution'
                            ? 'warn'
                            : 'info'
                      }
                    />
                  </td>
                  <td className="py-2.5 pr-3">
                    <StatusBadge
                      label={a.active ? 'active' : 'disabled'}
                      tone={a.active ? 'good' : 'neutral'}
                    />
                  </td>
                  <td className="py-2.5 text-right space-x-2">
                    <button
                      type="button"
                      onClick={() => {
                        setAddIns(a.ins);
                        setAddName(a.name);
                        setAddCategory(a.category);
                        setAddTier(
                          a.safety_tier as 'low' | 'caution' | 'avoid' | 'info',
                        );
                        setAddSummary(a.summary);
                        setAddNotes(a.dietary_notes);
                        setAddActive(a.active);
                      }}
                      className="rounded-lg border border-slate-200 px-2.5 py-1 text-[11px] font-semibold"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => void removeAdditive(a.ins)}
                      className="rounded-lg border border-rose-200 px-2.5 py-1 text-[11px] font-semibold text-rose-700 hover:bg-rose-50"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
              {!additives.length ? (
                <tr>
                  <td colSpan={5} className="py-4 text-center text-slate-500">
                    No live overrides yet — mobile app uses bundled JSON glossary.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </PanelCard>
    </div>
  );
}
