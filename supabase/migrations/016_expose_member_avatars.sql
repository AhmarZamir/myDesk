-- Expose profile avatars only through authorized relationship RPCs.
-- Buddies already receive avatar_url from get_my_buddies().
-- Shared Desk members now receive avatar_url only when the caller belongs to the same desk.

create or replace function public.get_desk_members(p_desk_id uuid)
returns table (
  user_id uuid,
  full_name text,
  avatar_url text,
  role text,
  is_me boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    dm.user_id,
    coalesce(nullif(p.full_name, ''), 'Member') as full_name,
    p.avatar_url,
    dm.role,
    dm.user_id = auth.uid() as is_me
  from public.desk_members dm
  join public.profiles p on p.id = dm.user_id
  where dm.desk_id = p_desk_id
    and public.is_desk_member(p_desk_id)
  order by (dm.user_id = auth.uid()) desc, p.full_name nulls last, dm.joined_at;
$$;

grant execute on function public.get_desk_members(uuid) to authenticated;
