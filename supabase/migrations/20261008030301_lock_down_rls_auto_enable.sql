-- Keep Supabase's automatic RLS event trigger, but prevent its helper from
-- being invoked through the public Data API.
do $migration$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$migration$;