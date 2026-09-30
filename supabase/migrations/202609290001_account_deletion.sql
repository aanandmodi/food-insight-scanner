begin;
create table if not exists public.account_deletion_guards (
  user_id text primary key,
  created_at timestamptz not null default now()
);
alter table public.account_deletion_guards enable row level security;
revoke all on public.account_deletion_guards from public, anon, authenticated;

create or replace function public.food_insight_uid() returns text
language sql stable security definer set search_path = '' as $$
  select case when auth.jwt()->>'iss' = 'https://securetoken.google.com/food-insight-scanner-app'
    and auth.jwt()->>'aud' = 'food-insight-scanner-app'
    and not exists (select 1 from public.account_deletion_guards d where d.user_id = auth.jwt()->>'sub')
    then nullif(auth.jwt()->>'sub', '') else null end
$$;

create or replace function public.delete_food_insight_user(owner_uid text)
returns void language plpgsql security definer set search_path = '' as $$
declare table_name text;
begin
  if owner_uid is null or length(owner_uid) = 0 or length(owner_uid) > 128 then
    raise exception 'Invalid account';
  end if;
  insert into public.account_deletion_guards(user_id) values(owner_uid) on conflict do nothing;
  foreach table_name in array array['profiles','scans','diet_entries','shopping_items','meal_plans','chat_messages','activity_logs'] loop
    execute format('delete from public.%I where user_id = $1', table_name) using owner_uid;
  end loop;
  delete from public.ai_request_limits where user_id = owner_uid;
end;
$$;
revoke all on function public.delete_food_insight_user(text) from public, anon, authenticated;
grant execute on function public.delete_food_insight_user(text) to service_role;
-- The minimal UID deletion guard deliberately remains to stop stale JWT writes.
-- No profile, meals, health data or images remain in this record.
commit;
