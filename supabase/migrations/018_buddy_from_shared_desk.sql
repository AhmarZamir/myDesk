-- Allow users who share a current Shared Desk to become Buddies directly.

create or replace function public.add_shared_desk_member_as_buddy(
  p_desk_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_low uuid;
  v_high uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_user_id is null or p_user_id = auth.uid() then
    raise exception 'Choose another member';
  end if;
  if not public.is_user_desk_member(p_desk_id, auth.uid())
     or not public.is_user_desk_member(p_desk_id, p_user_id) then
    raise exception 'Both users must be current members of this Shared Desk';
  end if;

  perform public.ensure_current_profile();
  v_low := least(auth.uid(), p_user_id);
  v_high := greatest(auth.uid(), p_user_id);

  insert into public.buddy_connections(user_low, user_high, created_by)
  values (v_low, v_high, auth.uid())
  on conflict (user_low, user_high) do nothing;

  insert into public.notifications(recipient_id, actor_id, kind, title, body)
  select p_user_id, auth.uid(), 'buddy', 'New Buddy connection',
         coalesce(nullif(p.full_name, ''), 'A Shared Desk member') || ' added you as a Buddy'
  from public.profiles p
  where p.id = auth.uid()
    and not exists (
      select 1 from public.notifications n
      where n.recipient_id = p_user_id
        and n.actor_id = auth.uid()
        and n.kind = 'buddy'
        and n.title = 'New Buddy connection'
        and n.created_at > now() - interval '1 minute'
    );
end;
$$;

grant execute on function public.add_shared_desk_member_as_buddy(uuid, uuid) to authenticated;
