-- Phase 4 Step 2: Scalable per-tier PostgreSQL AI quota, IP flood shield, and provider circuit health.
-- Replaces the single 200/day global Firestore budget kill-switch while keeping strict zero-trust RLS.
begin;

create table if not exists public.ai_user_quotas (
  user_id text not null,
  task text not null,
  day_date date not null default (now() at time zone 'utc')::date,
  daily_count integer not null default 0 check (daily_count >= 0),
  last_request_at timestamptz,
  primary key (user_id, task),
  check (length(user_id) > 0 and length(user_id) <= 128),
  check (task in ('chat', 'meal', 'plan', 'analysis', 'macros', 'quickReplies'))
);

alter table public.ai_user_quotas enable row level security;
alter table public.ai_user_quotas force row level security;
revoke all on public.ai_user_quotas from public, anon, authenticated;
grant select, insert, update, delete on public.ai_user_quotas to service_role;

create index if not exists ai_user_quotas_day_idx
  on public.ai_user_quotas (day_date desc, user_id);

create table if not exists public.ai_ip_rate_limits (
  ip_hash text primary key,
  window_start timestamptz not null,
  requests integer not null check (requests >= 0),
  check (length(ip_hash) > 0 and length(ip_hash) <= 128)
);

alter table public.ai_ip_rate_limits enable row level security;
alter table public.ai_ip_rate_limits force row level security;
revoke all on public.ai_ip_rate_limits from public, anon, authenticated;
grant select, insert, update, delete on public.ai_ip_rate_limits to service_role;

create table if not exists public.ai_provider_health (
  provider text primary key check (provider in ('groq', 'gemini')),
  cooldown_until timestamptz,
  consecutive_failures integer not null default 0 check (consecutive_failures >= 0),
  last_status integer,
  last_error_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.ai_provider_health enable row level security;
alter table public.ai_provider_health force row level security;
revoke all on public.ai_provider_health from public, anon, authenticated;
grant select, insert, update, delete on public.ai_provider_health to service_role;

create or replace function public.check_ip_rate_limit(
  p_ip_hash text,
  p_limit integer default 30
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_limit integer := greatest(1, least(500, coalesce(p_limit, 30)));
  v_row public.ai_ip_rate_limits%rowtype;
  v_retry integer;
begin
  if p_ip_hash is null or length(trim(p_ip_hash)) = 0 or length(p_ip_hash) > 128 then
    return jsonb_build_object('allowed', true, 'skipped', true);
  end if;

  insert into public.ai_ip_rate_limits (ip_hash, window_start, requests)
  values (p_ip_hash, v_now, 0)
  on conflict (ip_hash) do nothing;

  select * into v_row
  from public.ai_ip_rate_limits
  where ip_hash = p_ip_hash
  for update;

  if v_row.window_start <= v_now - interval '60 seconds' then
    update public.ai_ip_rate_limits
    set window_start = v_now, requests = 1
    where ip_hash = p_ip_hash;
    return jsonb_build_object('allowed', true, 'requests', 1, 'limit', v_limit);
  end if;

  if v_row.requests >= v_limit then
    v_retry := greatest(1, ceil(extract(epoch from ((v_row.window_start + interval '60 seconds') - v_now)))::integer);
    return jsonb_build_object(
      'allowed', false,
      'reason', 'ip-flood',
      'requests', v_row.requests,
      'limit', v_limit,
      'retryAfterSeconds', v_retry
    );
  end if;

  update public.ai_ip_rate_limits
  set requests = v_row.requests + 1
  where ip_hash = p_ip_hash;

  return jsonb_build_object('allowed', true, 'requests', v_row.requests + 1, 'limit', v_limit);
end;
$$;

revoke all on function public.check_ip_rate_limit(text, integer) from public, anon, authenticated;
grant execute on function public.check_ip_rate_limit(text, integer) to service_role;

create or replace function public.check_and_consume_ai_quota(
  p_user_id text,
  p_task text,
  p_is_guest boolean default false,
  p_daily_limit integer default null,
  p_cooldown_seconds integer default null,
  p_ip_hash text default null,
  p_ip_per_minute_limit integer default 30
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_today date := (v_now at time zone 'utc')::date;
  v_ip_check jsonb;
  v_default_limit integer;
  v_effective_limit integer;
  v_cooldown_secs integer;
  v_row public.ai_user_quotas%rowtype;
  v_count integer;
  v_retry integer;
begin
  if p_user_id is null or length(trim(p_user_id)) = 0 or length(p_user_id) > 128 then
    return jsonb_build_object('allowed', false, 'reason', 'invalid-user');
  end if;

  if p_task not in ('chat', 'meal', 'plan', 'analysis', 'macros', 'quickReplies') then
    return jsonb_build_object('allowed', false, 'reason', 'invalid-task');
  end if;

  -- Check hashed IP 30 req/min flood shield first without burning user quota.
  if p_ip_hash is not null and length(trim(p_ip_hash)) > 0 then
    v_ip_check := public.check_ip_rate_limit(p_ip_hash, p_ip_per_minute_limit);
    if coalesce((v_ip_check->>'allowed')::boolean, true) = false then
      return v_ip_check;
    end if;
  end if;

  -- Tier defaults: Guest (3 chat, 3 meal, 1 plan, 3 analysis, 30s burst) vs Verified Free (20 chat, 15 meal, 15 analysis, 2 plan, 2s burst).
  if p_is_guest then
    v_default_limit := case p_task
      when 'chat' then 3
      when 'meal' then 3
      when 'plan' then 1
      when 'analysis' then 3
      when 'macros' then 0
      when 'quickReplies' then 5
      else 1
    end;
    v_cooldown_secs := case when p_task = 'quickReplies' then 2 else coalesce(p_cooldown_seconds, 30) end;
    if p_daily_limit is not null and p_daily_limit >= 0 then
      v_effective_limit := least(v_default_limit, least(500, p_daily_limit));
    else
      v_effective_limit := v_default_limit;
    end if;
  else
    v_default_limit := case p_task
      when 'chat' then 20
      when 'meal' then 15
      when 'plan' then 2
      when 'analysis' then 15
      when 'macros' then 2
      when 'quickReplies' then 20
      else 10
    end;
    v_cooldown_secs := coalesce(p_cooldown_seconds, 2);
    if p_daily_limit is not null and p_daily_limit >= 0 then
      v_effective_limit := least(500, p_daily_limit);
    else
      v_effective_limit := v_default_limit;
    end if;
  end if;

  v_cooldown_secs := greatest(0, least(300, v_cooldown_secs));

  insert into public.ai_user_quotas (user_id, task, day_date, daily_count, last_request_at)
  values (p_user_id, p_task, v_today, 0, null)
  on conflict (user_id, task) do nothing;

  select * into v_row
  from public.ai_user_quotas
  where user_id = p_user_id and task = p_task
  for update;

  v_count := case when v_row.day_date = v_today then v_row.daily_count else 0 end;

  if v_cooldown_secs > 0 and v_row.last_request_at is not null
     and v_row.last_request_at > v_now - make_interval(secs => v_cooldown_secs) then
    v_retry := greatest(1, ceil(extract(epoch from ((v_row.last_request_at + make_interval(secs => v_cooldown_secs)) - v_now)))::integer);
    return jsonb_build_object(
      'allowed', false,
      'reason', 'burst',
      'used', v_count,
      'limit', v_effective_limit,
      'retryAfterSeconds', v_retry
    );
  end if;

  if v_count >= v_effective_limit then
    v_retry := greatest(60, ceil(extract(epoch from (((v_today + 1)::timestamp at time zone 'utc') - v_now)))::integer);
    return jsonb_build_object(
      'allowed', false,
      'reason', 'daily-quota',
      'used', v_count,
      'limit', v_effective_limit,
      'retryAfterSeconds', v_retry
    );
  end if;

  update public.ai_user_quotas
  set day_date = v_today,
      daily_count = v_count + 1,
      last_request_at = v_now
  where user_id = p_user_id and task = p_task;

  return jsonb_build_object(
    'allowed', true,
    'used', v_count + 1,
    'limit', v_effective_limit,
    'remaining', greatest(0, v_effective_limit - (v_count + 1))
  );
end;
$$;

revoke all on function public.check_and_consume_ai_quota(text, text, boolean, integer, integer, text, integer) from public, anon, authenticated;
grant execute on function public.check_and_consume_ai_quota(text, text, boolean, integer, integer, text, integer) to service_role;

-- Update cascading deletion cleanup to also clear ai_user_quotas.
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
