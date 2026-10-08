-- Server-owned lifetime quota for the hosted ChemVision AI service.
-- The app can never read or modify these counters directly.
create table if not exists public.chemvision_ai_usage (
  user_id uuid primary key references auth.users (id) on delete cascade,
  used_count integer not null default 0 check (used_count >= 0),
  reserved_count integer not null default 0 check (reserved_count >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.chemvision_ai_usage_requests (
  request_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('reserved', 'completed', 'failed', 'expired')),
  total_tokens integer check (total_tokens is null or total_tokens >= 0),
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create index if not exists chemvision_ai_usage_requests_user_status_created_idx
  on public.chemvision_ai_usage_requests (user_id, status, created_at);

alter table public.chemvision_ai_usage enable row level security;
alter table public.chemvision_ai_usage_requests enable row level security;

revoke all on table public.chemvision_ai_usage
  from public, anon, authenticated;
revoke all on table public.chemvision_ai_usage_requests
  from public, anon, authenticated;
grant select, insert, update, delete on table public.chemvision_ai_usage
  to service_role;
grant select, insert, update, delete on table public.chemvision_ai_usage_requests
  to service_role;

create or replace function public.reserve_chemvision_ai_call(
  p_user_id uuid,
  p_limit integer default 5
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usage public.chemvision_ai_usage%rowtype;
  v_stale_count integer;
  v_request_id uuid;
begin
  if p_user_id is null or p_limit < 1 then
    raise exception 'invalid reservation arguments';
  end if;

  insert into public.chemvision_ai_usage (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select * into v_usage
  from public.chemvision_ai_usage
  where user_id = p_user_id
  for update;

  -- Recover reservations from an Edge Function that was terminated mid-call.
  update public.chemvision_ai_usage_requests
  set status = 'expired', finished_at = now()
  where user_id = p_user_id
    and status = 'reserved'
    and created_at < now() - interval '15 minutes';
  get diagnostics v_stale_count = row_count;

  if v_stale_count > 0 then
    update public.chemvision_ai_usage
    set reserved_count = greatest(0, reserved_count - v_stale_count),
        updated_at = now()
    where user_id = p_user_id;
    select * into v_usage
    from public.chemvision_ai_usage
    where user_id = p_user_id;
  end if;

  if v_usage.used_count + v_usage.reserved_count >= p_limit then
    return jsonb_build_object(
      'allowed', false,
      'used', v_usage.used_count,
      'reserved', v_usage.reserved_count,
      'limit', p_limit,
      'remaining', greatest(0, p_limit - v_usage.used_count - v_usage.reserved_count)
    );
  end if;

  insert into public.chemvision_ai_usage_requests (user_id, status)
  values (p_user_id, 'reserved')
  returning request_id into v_request_id;

  update public.chemvision_ai_usage
  set reserved_count = reserved_count + 1,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_usage;

  return jsonb_build_object(
    'allowed', true,
    'requestId', v_request_id,
    'used', v_usage.used_count,
    'reserved', v_usage.reserved_count,
    'limit', p_limit,
    'remaining', greatest(0, p_limit - v_usage.used_count - v_usage.reserved_count)
  );
end;
$$;

create or replace function public.finalize_chemvision_ai_call(
  p_request_id uuid,
  p_succeeded boolean,
  p_total_tokens integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_status text;
  v_usage public.chemvision_ai_usage%rowtype;
begin
  if p_request_id is null then
    raise exception 'request id is required';
  end if;
  if p_total_tokens is not null and p_total_tokens < 0 then
    raise exception 'token count cannot be negative';
  end if;

  select user_id into v_user_id
  from public.chemvision_ai_usage_requests
  where request_id = p_request_id;
  if not found then
    return jsonb_build_object('ok', false);
  end if;

  select * into v_usage
  from public.chemvision_ai_usage
  where user_id = v_user_id
  for update;

  select status into v_status
  from public.chemvision_ai_usage_requests
  where request_id = p_request_id
  for update;

  if v_status = 'reserved' then
    update public.chemvision_ai_usage
    set reserved_count = greatest(0, reserved_count - 1),
        used_count = used_count + case when p_succeeded then 1 else 0 end,
        updated_at = now()
    where user_id = v_user_id
    returning * into v_usage;

    update public.chemvision_ai_usage_requests
    set status = case when p_succeeded then 'completed' else 'failed' end,
        total_tokens = case when p_succeeded then p_total_tokens else null end,
        finished_at = now()
    where request_id = p_request_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'used', v_usage.used_count,
    'reserved', v_usage.reserved_count,
    'limit', 5,
    'remaining', greatest(0, 5 - v_usage.used_count - v_usage.reserved_count)
  );
end;
$$;

revoke all on function public.reserve_chemvision_ai_call(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.finalize_chemvision_ai_call(uuid, boolean, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_chemvision_ai_call(uuid, integer)
  to service_role;
grant execute on function public.finalize_chemvision_ai_call(uuid, boolean, integer)
  to service_role;
