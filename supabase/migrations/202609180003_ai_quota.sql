create table if not exists public.ai_request_limits (
  user_id text primary key,
  window_start timestamptz not null,
  requests integer not null
);
alter table public.ai_request_limits enable row level security;
revoke all on public.ai_request_limits from public, anon, authenticated;

create or replace function public.consume_ai_quota(owner_uid text)
returns boolean language plpgsql security definer set search_path = public
as $$
declare count_now integer;
begin
  if owner_uid is null or length(owner_uid) = 0 or length(owner_uid) > 128 then
    return false;
  end if;
  insert into public.ai_request_limits as q (user_id, window_start, requests)
  values (owner_uid, now(), 1)
  on conflict (user_id) do update set
    requests = case when q.window_start < now() - interval '10 minutes' then 1 else q.requests + 1 end,
    window_start = case when q.window_start < now() - interval '10 minutes' then now() else q.window_start end
  returning requests into count_now;
  return count_now <= 60;
end;
$$;
revoke all on function public.consume_ai_quota(text) from public, anon, authenticated;
grant execute on function public.consume_ai_quota(text) to service_role;
