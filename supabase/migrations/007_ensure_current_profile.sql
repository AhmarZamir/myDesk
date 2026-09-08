-- Guarantee that every authenticated user has a matching public.profiles row.
-- This is safe to call repeatedly and also repairs users created before the profile trigger existed.

create or replace function public.ensure_current_profile()
returns public.profiles
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_profile public.profiles;
  current_user auth.users;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into current_user
  from auth.users
  where id = auth.uid();

  if current_user.id is null then
    raise exception 'Authenticated user could not be found';
  end if;

  insert into public.profiles (id, full_name)
  values (
    current_user.id,
    coalesce(current_user.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do update
    set updated_at = now();

  select * into current_profile
  from public.profiles
  where id = current_user.id;

  return current_profile;
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
