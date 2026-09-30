begin;
-- Preserve objects while closing public access to legacy personal uploads.
update storage.buckets set public = false where id = 'food-insight-uploads';
create policy food_insight_legacy_owner on storage.objects for all to anon, authenticated
using (bucket_id = 'food-insight-uploads' and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = (select public.food_insight_uid()))
with check (bucket_id = 'food-insight-uploads' and (storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = (select public.food_insight_uid()));
create policy food_insight_legacy_guard on storage.objects as restrictive for all to anon, authenticated
using (bucket_id <> 'food-insight-uploads' or ((storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = (select public.food_insight_uid())))
with check (bucket_id <> 'food-insight-uploads' or ((storage.foldername(name))[1] = 'users'
  and (storage.foldername(name))[2] = (select public.food_insight_uid())));
commit;
