import { useCallback, useEffect, useState } from 'react';
import {
  Activity,
  FileCheck2,
  LayoutDashboard,
  LogOut,
  PackageSearch,
  RefreshCw,
  Shield,
  Sliders,
  Users,
} from 'lucide-react';
import {
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
  type User,
} from 'firebase/auth';

import { ToastBanner } from './components/UiPrimitives';
import { firebaseAuth, isFirebaseConfigured } from './lib/firebase';
import { CatalogModerationPage } from './pages/CatalogModerationPage';
import { FlagsConfigPage } from './pages/FlagsConfigPage';
import { OverviewPage } from './pages/OverviewPage';
import { QuotasHealthPage } from './pages/QuotasHealthPage';
import { UsersGovernancePage } from './pages/UsersGovernancePage';

type TabKey = 'overview' | 'flags' | 'quotas' | 'catalog' | 'users';

const NAV_ITEMS: Array<{ key: TabKey; label: string; icon: typeof LayoutDashboard }> = [
  { key: 'overview', label: 'Overview', icon: LayoutDashboard },
  { key: 'flags', label: 'Flags & Release', icon: Sliders },
  { key: 'quotas', label: 'Quotas & Abuse', icon: Activity },
  { key: 'catalog', label: 'Catalog & Additives', icon: PackageSearch },
  { key: 'users', label: 'Users & Audit', icon: Users },
];

export function App() {
  const [user, setUser] = useState<User | null>(null);
  const [authReady, setAuthReady] = useState(!firebaseAuth);
  const [isAdminClaim, setIsAdminClaim] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [authError, setAuthError] = useState('');
  const [signingIn, setSigningIn] = useState(false);

  const [tab, setTab] = useState<TabKey>('overview');
  const [toast, setToast] = useState<{ type: 'success' | 'error'; message: string } | null>(
    null,
  );

  const notify = useCallback((type: 'success' | 'error', message: string) => {
    setToast({ type, message });
  }, []);

  const refreshClaims = useCallback(async (u: User | null) => {
    if (!u) {
      setIsAdminClaim(false);
      return;
    }
    try {
      const token = await u.getIdTokenResult(true);
      setIsAdminClaim(
        !u.isAnonymous &&
          u.emailVerified === true &&
          (token.claims.role === 'admin' || token.claims.admin === true),
      );
    } catch {
      setIsAdminClaim(false);
    }
  }, []);

  useEffect(() => {
    if (!firebaseAuth) return;
    return onAuthStateChanged(firebaseAuth, (nextUser) => {
      setUser(nextUser);
      setAuthReady(true);
      void refreshClaims(nextUser);
    });
  }, [refreshClaims]);

  if (!isFirebaseConfigured || !firebaseAuth) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="max-w-lg rounded-2xl border border-amber-200 bg-white p-6 shadow-sm">
          <div className="flex items-center gap-2 text-amber-800">
            <Shield className="h-5 w-5" />
            <h1 className="text-base font-bold">Admin Portal Firebase Config Needed</h1>
          </div>
          <p className="mt-2 text-sm text-slate-600">
            Populate <code>admin-web/.env.local</code> or <code>.env.production</code> from{' '}
            <code>.env.example</code> with the Firebase Web App SDK keys for{' '}
            <code>food-insight-scanner-app</code> and rebuild.
          </p>
        </div>
      </div>
    );
  }

  if (!authReady) {
    return (
      <div className="flex min-h-screen items-center justify-center text-sm text-slate-500">
        Checking session…
      </div>
    );
  }

  if (!user) {
    const submitEmail = async (e: React.FormEvent) => {
      e.preventDefault();
      setAuthError('');
      setSigningIn(true);
      try {
        await signInWithEmailAndPassword(firebaseAuth!, email.trim(), password);
      } catch (err) {
        setAuthError(err instanceof Error ? err.message : 'Sign-in failed.');
      } finally {
        setSigningIn(false);
      }
    };

    const signInGoogle = async () => {
      setAuthError('');
      setSigningIn(true);
      try {
        await signInWithPopup(firebaseAuth!, new GoogleAuthProvider());
      } catch (err) {
        setAuthError(err instanceof Error ? err.message : 'Google sign-in failed.');
      } finally {
        setSigningIn(false);
      }
    };

    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-7 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-600 text-white">
              <FileCheck2 className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-lg font-bold text-slate-900">
                Food Insight Admin Portal
              </h1>
              <p className="text-xs text-slate-500">
                Restricted to verified administrator accounts
              </p>
            </div>
          </div>

          <form onSubmit={(e) => void submitEmail(e)} className="mt-6 space-y-3">
            <input
              type="email"
              required
              placeholder="Admin email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-xl border border-slate-300 px-3.5 py-2.5 text-sm"
            />
            <input
              type="password"
              required
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-xl border border-slate-300 px-3.5 py-2.5 text-sm"
            />
            {authError ? (
              <p className="text-xs font-medium text-rose-600">{authError}</p>
            ) : null}
            <button
              type="submit"
              disabled={signingIn}
              className="w-full rounded-xl bg-emerald-600 py-2.5 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
            >
              {signingIn ? 'Signing in…' : 'Sign in with Email'}
            </button>
          </form>

          <div className="my-4 flex items-center gap-3 text-xs text-slate-400">
            <div className="h-px flex-1 bg-slate-200" />
            <span>OR</span>
            <div className="h-px flex-1 bg-slate-200" />
          </div>

          <button
            type="button"
            disabled={signingIn}
            onClick={() => void signInGoogle()}
            className="w-full rounded-xl border border-slate-300 bg-white py-2.5 text-sm font-semibold text-slate-700 hover:bg-slate-50"
          >
            Continue with Google
          </button>
        </div>
      </div>
    );
  }

  if (!isAdminClaim) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="max-w-lg rounded-2xl border border-slate-200 bg-white p-7 shadow-sm">
          <h1 className="text-lg font-bold text-slate-900">Admin Role Required</h1>
          <p className="mt-2 text-sm text-slate-600">
            Signed in as <strong>{user.email ?? user.uid}</strong>, which does not
            currently hold verified <code>role: &quot;admin&quot;</code> claims.
          </p>
          <div className="mt-3 rounded-xl bg-slate-100 p-3 font-mono text-xs text-slate-700">
            UID: {user.uid}
            <br />
            Email verified: {String(user.emailVerified)}
          </div>
          <p className="mt-3 text-xs text-slate-500">
            Grant access offline via{' '}
            <code>node tools/set_admin_claim.mjs --uid {user.uid} --service-account ...</code>{' '}
            then click Refresh Permissions.
          </p>
          <div className="mt-5 flex gap-2.5">
            <button
              type="button"
              onClick={() => void refreshClaims(user)}
              className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-700"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              Refresh Permissions
            </button>
            <button
              type="button"
              onClick={() => void signOut(firebaseAuth!)}
              className="rounded-xl border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-50"
            >
              Sign out
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/95 backdrop-blur-xs">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-600 text-white">
              <FileCheck2 className="h-5 w-5" />
            </div>
            <div>
              <div className="text-sm font-bold text-slate-900">Food Insight Admin</div>
              <div className="text-[11px] text-slate-500">{user.email}</div>
            </div>
          </div>

          <nav className="flex flex-wrap items-center gap-1">
            {NAV_ITEMS.map((item) => {
              const Icon = item.icon;
              const active = tab === item.key;
              return (
                <button
                  key={item.key}
                  type="button"
                  onClick={() => setTab(item.key)}
                  className={`inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold transition ${
                    active
                      ? 'bg-emerald-600 text-white shadow-2xs'
                      : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                  }`}
                >
                  <Icon className="h-3.5 w-3.5" />
                  {item.label}
                </button>
              );
            })}
          </nav>

          <button
            type="button"
            onClick={() => void signOut(firebaseAuth!)}
            className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-50"
          >
            <LogOut className="h-3.5 w-3.5" />
            Sign out
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
        <ToastBanner toast={toast} onDismiss={() => setToast(null)} />
        {tab === 'overview' ? (
          <OverviewPage onNotify={notify} onNavigate={(next) => setTab(next)} />
        ) : null}
        {tab === 'flags' ? <FlagsConfigPage onNotify={notify} /> : null}
        {tab === 'quotas' ? <QuotasHealthPage onNotify={notify} /> : null}
        {tab === 'catalog' ? <CatalogModerationPage onNotify={notify} /> : null}
        {tab === 'users' ? <UsersGovernancePage onNotify={notify} /> : null}
      </main>
    </div>
  );
}
export default App;
