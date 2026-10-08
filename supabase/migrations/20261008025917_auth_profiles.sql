-- 每个 Supabase Auth 用户对应一份可自行编辑的公开资料。
-- Owner 权限不保存在客户端可写字段中，而由已验证的 GitHub identity 判定。
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all on table public.profiles from public, anon, authenticated;
grant select (id, display_name, avatar_url, created_at, updated_at)
  on table public.profiles to authenticated;
grant update (display_name, avatar_url)
  on table public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_profile_updated_at() from public, anon, authenticated;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_profile_updated_at();

create or replace function public.create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(new.raw_user_meta_data ->> 'user_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'ChemVision 用户'
    ),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.create_profile_for_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.create_profile_for_auth_user();

-- 为迁移前已存在的 Auth 账号补建 profile；metadata 仅用于展示，不授予权限。
insert into public.profiles (id, display_name, avatar_url)
select
  users.id,
  coalesce(
    nullif(users.raw_user_meta_data ->> 'full_name', ''),
    nullif(users.raw_user_meta_data ->> 'name', ''),
    nullif(users.raw_user_meta_data ->> 'user_name', ''),
    nullif(split_part(coalesce(users.email, ''), '@', 1), ''),
    'ChemVision 用户'
  ),
  nullif(users.raw_user_meta_data ->> 'avatar_url', '')
from auth.users as users
on conflict (id) do nothing;

-- 只有通过 GitHub OAuth 建立的、用户名为 panda-lsy 的 identity 才是仓库 Owner。
-- 不使用 raw_user_meta_data/app_metadata 中由客户端可修改的用户名或角色。
create or replace function public.is_chemvision_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.identities as identities
    where identities.user_id = (select auth.uid())
      and identities.provider = 'github'
      and lower(coalesce(
        identities.identity_data ->> 'user_name',
        identities.identity_data ->> 'login',
        ''
      )) = 'panda-lsy'
  );
$$;

revoke all on function public.is_chemvision_owner() from public, anon;
grant execute on function public.is_chemvision_owner() to authenticated;
