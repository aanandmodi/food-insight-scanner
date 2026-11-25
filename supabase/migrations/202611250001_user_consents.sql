-- Legal Terms of Use, Privacy Policy, and Health Data Processing consent audit log.
begin;

create table if not exists public.user_consents (
  user_id text not null,
  terms_version text not null,
  privacy_version text not null,
  health_data_consent boolean not null default false,
  app_version text not null default '',
  accepted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, terms_version, privacy_version),
  check (length(user_id) > 0 and length(user_id) <= 128),
  check (length(terms_version) > 0 and length(terms_version) <= 64),
  check (length(privacy_version) > 0 and length(privacy_version) <= 64),
  check (health_data_consent = true)
);

alter table public.user_consents enable row level security;
alter table public.user_consents force row level security;

drop policy if exists food_insight_consents_owner on public.user_consents;
create policy food_insight_consents_owner on public.user_consents
  for all to anon, authenticated
  using (user_id = (select public.food_insight_uid()))
  with check (user_id = (select public.food_insight_uid()));

drop policy if exists food_insight_consents_guard on public.user_consents;
create policy food_insight_consents_guard on public.user_consents
  as restrictive for all to anon, authenticated
  using (user_id = (select public.food_insight_uid()))
  with check (user_id = (select public.food_insight_uid()));

grant select, insert, update, delete on public.user_consents to anon, authenticated;

create index if not exists user_consents_owner_accepted
  on public.user_consents (user_id, accepted_at desc);

-- Ensure cascading account deletion purges user_consents alongside core user tables.
create or replace function public.delete_food_insight_user(owner_uid text)
returns void language plpgsql security definer set search_path = '' as $$
declare table_name text;
begin
  if owner_uid is null or length(owner_uid) = 0 or length(owner_uid) > 128 then
    raise exception 'Invalid account';
  end if;
  insert into public.account_deletion_guards(user_id) values(owner_uid) on conflict do nothing;
  foreach table_name in array array['profiles','scans','diet_entries','shopping_items','meal_plans','chat_messages','activity_logs','user_consents'] loop
    execute format('delete from public.%I where user_id = $1', table_name) using owner_uid;
  end loop;
  delete from public.ai_request_limits where user_id = owner_uid;
end;
$$;
revoke all on function public.delete_food_insight_user(text) from public, anon, authenticated;
grant execute on function public.delete_food_insight_user(text) to service_role;

commit;
