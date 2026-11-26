-- Phase 5 Step 1: Admin Web Portal schema, product moderation queue, deletion queue,
-- account suspensions, live additive overrides, and immutable admin audit logging.
begin;

-- 1. Account suspensions (checked in Supabase RLS helper AND Firebase Edge handlers).
create table if not exists public.user_suspensions (
  user_id text primary key,
  active boolean not null default true,
  reason text not null default '',
  updated_by text not null default '',
  updated_at timestamptz not null default now(),
  check (length(user_id) > 0 and length(user_id) <= 128),
  check (length(reason) <= 400),
  check (length(updated_by) <= 128)
);

alter table public.user_suspensions enable row level security;
alter table public.user_suspensions force row level security;
revoke all on public.user_suspensions from public, anon, authenticated;
grant select, insert, update, delete on public.user_suspensions to service_role;

-- Update UID extractor so suspended or deleted accounts fail RLS immediately even with cached JWTs.
create or replace function public.food_insight_uid() returns text
language sql stable security definer set search_path = '' as $$
  select case when auth.jwt()->>'iss' = 'https://securetoken.google.com/food-insight-scanner-app'
    and auth.jwt()->>'aud' = 'food-insight-scanner-app'
    and not exists (select 1 from public.account_deletion_guards d where d.user_id = auth.jwt()->>'sub')
    and not exists (select 1 from public.user_suspensions s where s.user_id = auth.jwt()->>'sub' and s.active = true)
    then nullif(auth.jwt()->>'sub', '') else null end
$$;

-- 2. Immutable admin action audit log (service_role only).
create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_uid text not null,
  admin_email text not null default '',
  action text not null,
  target_type text not null,
  target_id text not null default '',
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  created_at timestamptz not null default now(),
  check (length(admin_uid) > 0 and length(admin_uid) <= 128),
  check (length(admin_email) <= 320),
  check (length(action) > 0 and length(action) <= 64),
  check (length(target_type) > 0 and length(target_type) <= 64),
  check (length(target_id) <= 160)
);

alter table public.admin_audit_logs enable row level security;
alter table public.admin_audit_logs force row level security;
revoke all on public.admin_audit_logs from public, anon, authenticated;
grant select, insert on public.admin_audit_logs to service_role;

create index if not exists admin_audit_logs_created_idx
  on public.admin_audit_logs (created_at desc);

create index if not exists admin_audit_logs_admin_idx
  on public.admin_audit_logs (admin_uid, created_at desc);

-- 3. User-submitted inaccurate barcode / nutrition reports (owners can create open reports and view their own).
create table if not exists public.product_reports (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  barcode text not null,
  product_name text not null default '',
  issue_type text not null check (issue_type in ('wrong_nutrition', 'missing_allergen', 'wrong_ingredients', 'wrong_product', 'other')),
  notes text not null default '',
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  resolution_note text not null default '',
  resolved_by text not null default '',
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(user_id) > 0 and length(user_id) <= 128),
  check (barcode ~ '^[0-9]{8,14}$'),
  check (length(product_name) <= 160),
  check (length(notes) <= 600),
  check (length(resolution_note) <= 500),
  check (length(resolved_by) <= 128)
);

alter table public.product_reports enable row level security;
alter table public.product_reports force row level security;

drop policy if exists food_insight_reports_owner_select on public.product_reports;
create policy food_insight_reports_owner_select on public.product_reports
  for select to anon, authenticated
  using (user_id = (select public.food_insight_uid()));

drop policy if exists food_insight_reports_owner_insert on public.product_reports;
create policy food_insight_reports_owner_insert on public.product_reports
  for insert to anon, authenticated
  with check (
    user_id = (select public.food_insight_uid())
    and status = 'open'
    and resolution_note = ''
    and resolved_by = ''
    and resolved_at is null
  );

revoke all on public.product_reports from public, anon, authenticated;
grant select, insert on public.product_reports to anon, authenticated;
grant select, insert, update, delete on public.product_reports to service_role;

create index if not exists product_reports_status_created_idx
  on public.product_reports (status, created_at desc);

create index if not exists product_reports_owner_created_idx
  on public.product_reports (user_id, created_at desc);

-- 4. External / manual account deletion requests queue (service_role only).
create table if not exists public.deletion_requests (
  id uuid primary key default gen_random_uuid(),
  request_email text not null default '',
  target_uid text not null default '',
  source text not null default 'web_email' check (source in ('web_email', 'support', 'admin')),
  notes text not null default '',
  status text not null default 'pending' check (status in ('pending', 'completed', 'rejected')),
  resolution_note text not null default '',
  resolved_by text not null default '',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (length(request_email) <= 320),
  check (length(target_uid) <= 128),
  check (length(notes) <= 600),
  check (length(resolution_note) <= 500),
  check (length(resolved_by) <= 128),
  check (length(trim(request_email)) > 0 or length(trim(target_uid)) > 0)
);

alter table public.deletion_requests enable row level security;
alter table public.deletion_requests force row level security;
revoke all on public.deletion_requests from public, anon, authenticated;
grant select, insert, update, delete on public.deletion_requests to service_role;

create index if not exists deletion_requests_status_created_idx
  on public.deletion_requests (status, created_at desc);

-- 5. Live admin-managed INS/E additive glossary overrides (authenticated app read-only; admin writes).
create table if not exists public.food_additives_overrides (
  ins text primary key,
  name text not null,
  category text not null default 'Additive',
  safety_tier text not null default 'caution' check (safety_tier in ('low', 'caution', 'avoid', 'info')),
  summary text not null default '',
  dietary_notes text not null default '',
  active boolean not null default true,
  updated_by text not null default '',
  updated_at timestamptz not null default now(),
  check (length(ins) > 0 and length(ins) <= 24),
  check (length(name) > 0 and length(name) <= 160),
  check (length(category) <= 80),
  check (length(summary) <= 600),
  check (length(dietary_notes) <= 300),
  check (length(updated_by) <= 128)
);

alter table public.food_additives_overrides enable row level security;
alter table public.food_additives_overrides force row level security;

drop policy if exists food_insight_additives_read on public.food_additives_overrides;
create policy food_insight_additives_read on public.food_additives_overrides
  for select to anon, authenticated
  using ((select public.food_insight_uid()) is not null and active = true);

revoke all on public.food_additives_overrides from public, anon, authenticated;
grant select on public.food_additives_overrides to anon, authenticated;
grant select, insert, update, delete on public.food_additives_overrides to service_role;

-- 6. Extend cascading user deletion to also clear product_reports and suspension rows.
create or replace function public.delete_food_insight_user(owner_uid text)
returns void language plpgsql security definer set search_path = '' as $$
declare table_name text;
begin
  if owner_uid is null or length(owner_uid) = 0 or length(owner_uid) > 128 then
    raise exception 'Invalid account';
  end if;
  insert into public.account_deletion_guards(user_id) values(owner_uid) on conflict do nothing;
  foreach table_name in array array[
    'profiles',
    'scans',
    'diet_entries',
    'shopping_items',
    'meal_plans',
    'chat_messages',
    'chat_sessions',
    'activity_logs',
    'user_consents',
    'ai_abuse_events',
    'ai_user_quotas',
    'product_reports',
    'user_suspensions'
  ] loop
    execute format('delete from public.%I where user_id = $1', table_name) using owner_uid;
  end loop;
  delete from public.ai_request_limits where user_id = owner_uid;
end;
$$;

revoke all on function public.delete_food_insight_user(text) from public, anon, authenticated;
grant execute on function public.delete_food_insight_user(text) to service_role;

commit;
