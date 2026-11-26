-- AI prompt-injection & safety-override abuse telemetry (Admin-only via service_role).
-- Stores only metadata and a bounded non-PII rule match snippet; never raw health data.
begin;

create table if not exists public.ai_abuse_events (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  task text not null,
  category text not null,
  severity text not null check (severity in ('low', 'medium', 'high')),
  rule_id text not null,
  snippet text not null default '',
  created_at timestamptz not null default now(),
  check (length(user_id) > 0 and length(user_id) <= 128),
  check (length(task) > 0 and length(task) <= 32),
  check (length(category) > 0 and length(category) <= 64),
  check (length(rule_id) > 0 and length(rule_id) <= 64),
  check (length(snippet) <= 160)
);

alter table public.ai_abuse_events enable row level security;
alter table public.ai_abuse_events force row level security;

revoke all on public.ai_abuse_events from public, anon, authenticated;
grant select, insert, delete on public.ai_abuse_events to service_role;

create index if not exists ai_abuse_events_owner_created
  on public.ai_abuse_events (user_id, created_at desc);

create index if not exists ai_abuse_events_created
  on public.ai_abuse_events (created_at desc);

-- Ensure cascading account deletion purges ai_abuse_events alongside all user tables.
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
    'activity_logs',
    'user_consents',
    'ai_abuse_events'
  ] loop
    execute format('delete from public.%I where user_id = $1', table_name) using owner_uid;
  end loop;
  delete from public.ai_request_limits where user_id = owner_uid;
end;
$$;

revoke all on function public.delete_food_insight_user(text) from public, anon, authenticated;
grant execute on function public.delete_food_insight_user(text) to service_role;

commit;
