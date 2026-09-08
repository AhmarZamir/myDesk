-- Guarantee that every authenticated user has a matching public.profiles row.
-- Safe to call repeatedly and repairs users created before the profile trigger existed.

create or replace function public.ensure_current_profile()
returns public.profiles
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_profile public.profiles;
  v_user_id uuid;
  v_full_name text;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select coalesce(u.raw_user_meta_data ->> 'full_name', '')
  into v_full_name
  from auth.users u
  where u.id = v_user_id;

  if not found then
    raise exception 'Authenticated user could not be found';
  end if;

  insert into public.profiles (id, full_name)
  values (v_user_id, v_full_name)
  on conflict (id) do update
    set updated_at = now();

  select p.*
  into v_profile
  from public.profiles p
  where p.id = v_user_id;

  return v_profile;
end;
$$;

grant execute on function public.ensure_current_profile() to authenticated;

-- Repair all currently existing auth users as part of the migration.
insert into public.profiles (id, full_name)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', '')
from auth.users u
on conflict (id) do nothing;
