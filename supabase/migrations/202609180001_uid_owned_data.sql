-- Additive migration: existing tables and legacy files are preserved.
-- Firebase UIDs are strings, NOT Supabase auth.users UUIDs.
begin;
create or replace function public.food_insight_uid() returns text
language sql stable set search_path = '' as $$
  select case when auth.jwt()->>'iss' = 'https://securetoken.google.com/food-insight-scanner-app'
    and auth.jwt()->>'aud' = 'food-insight-scanner-app'
    then nullif(auth.jwt()->>'sub', '') else null end
$$;

do $$
declare t text;
begin
  foreach t in array array['profiles','scans','diet_entries','shopping_items','meal_plans','chat_messages','activity_logs'] loop
    execute format('create table if not exists public.%I (
      user_id text not null, id text not null,
      data jsonb not null default ''{}''::jsonb check (jsonb_typeof(data) = ''object''),
      updated_at timestamptz not null default now(), deleted boolean not null default false,
      primary key(user_id, id), check (length(user_id) > 0), check (length(id) > 0)
    )', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    -- Firebase tokens without a role claim are mapped to anon by PostgREST.
    -- Both roles must present a verified JWT from OUR project with the SAME UID.
    -- The public/publishable key alone has no matching issuer/sub and is denied.
    execute format('create policy food_insight_owner on public.%I for all to anon, authenticated
      using (user_id = (select public.food_insight_uid()))
      with check (user_id = (select public.food_insight_uid()))', t);
    -- Restrictive guard prevents any older broad policy granting cross-user access.
    execute format('create policy food_insight_owner_guard on public.%I as restrictive for all to anon, authenticated
      using (user_id = (select public.food_insight_uid()))
      with check (user_id = (select public.food_insight_uid()))', t);
    execute format('grant select, insert, update, delete on public.%I to anon, authenticated', t);
    execute format('create index %I on public.%I (user_id, updated_at desc)', t || '_owner_updated', t);
  end loop;
end $$;
create unique index profiles_one_per_uid on public.profiles(user_id);
alter table public.profiles add constraint profiles_fixed_id check (id = 'profile');
create index diet_entries_owner_date on public.diet_entries(user_id, (data->>'date')) where not deleted;
create index scans_owner_barcode on public.scans(user_id, (data->>'barcode')) where not deleted;

-- A new private bucket avoids silently changing accessibility of legacy uploads.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('food-insight-private', 'food-insight-private', false, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy food_insight_private_owner on storage.objects for all to anon, authenticated
using (bucket_id = 'food-insight-private' and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = (select public.food_insight_uid()))
with check (bucket_id = 'food-insight-private' and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = (select public.food_insight_uid()));
create policy food_insight_private_guard on storage.objects as restrictive for all to anon, authenticated
using (bucket_id <> 'food-insight-private' or
  ((storage.foldername(name))[1] = 'users' and (storage.foldername(name))[2] = (select public.food_insight_uid())))
with check (bucket_id <> 'food-insight-private' or
  ((storage.foldername(name))[1] = 'users' and (storage.foldername(name))[2] = (select public.food_insight_uid())));
commit;
