-- Phase 4 Step 3: Persistent multi-thread chat_sessions table with strict UID-owned RLS.
begin;

create table if not exists public.chat_sessions (
  user_id text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  primary key (user_id, id),
  check (length(user_id) > 0),
  check (length(id) > 0)
);

alter table public.chat_sessions enable row level security;
alter table public.chat_sessions force row level security;

drop policy if exists food_insight_owner on public.chat_sessions;
create policy food_insight_owner on public.chat_sessions
  for all to anon, authenticated
  using (user_id = (select public.food_insight_uid()))
  with check (user_id = (select public.food_insight_uid()));

drop policy if exists food_insight_owner_guard on public.chat_sessions;
create policy food_insight_owner_guard on public.chat_sessions
  as restrictive for all to anon, authenticated
  using (user_id = (select public.food_insight_uid()))
  with check (user_id = (select public.food_insight_uid()));

grant select, insert, update, delete on public.chat_sessions to anon, authenticated;

create index if not exists chat_sessions_owner_updated
  on public.chat_sessions (user_id, updated_at desc);

create index if not exists chat_messages_owner_session
  on public.chat_messages (user_id, (data->>'sessionId'))
  where not deleted;

-- Ensure cascading account deletion purges chat_sessions cleanly alongside all user tables.
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
    'ai_user_quotas'
  ] loop
    execute format('delete from public.%I where user_id = $1', table_name) using owner_uid;
  end loop;
  delete from public.ai_request_limits where user_id = owner_uid;
end;
$$;

revoke all on function public.delete_food_insight_user(text) from public, anon, authenticated;
grant execute on function public.delete_food_insight_user(text) to service_role;

commit;
