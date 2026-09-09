-- Complete the Shared Desk lifecycle and remove stale grant visibility.

create or replace function public.transfer_desk_ownership(
  p_desk_id uuid,
  p_new_owner_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.owns_desk(p_desk_id) then
    raise exception 'Only the current owner can transfer ownership';
  end if;
  if p_new_owner_id = auth.uid() then
    raise exception 'You already own this desk';
  end if;
  if not public.is_user_desk_member(p_desk_id, p_new_owner_id) then
    raise exception 'The new owner must already be a desk member';
  end if;

  update public.desk_members
  set role = 'admin'
  where desk_id = p_desk_id and user_id = auth.uid();

  update public.desk_members
  set role = 'owner'
  where desk_id = p_desk_id and user_id = p_new_owner_id;

  update public.desks
  set owner_id = p_new_owner_id
  where id = p_desk_id;
end;
$$;

grant execute on function public.transfer_desk_ownership(uuid, uuid) to authenticated;

-- A recipient should only see a custom access grant while the grant is still usable.
drop policy if exists "Recipients can read own grants" on public.document_access;
create policy "Recipients can read active own grants"
on public.document_access for select to authenticated
using (
  user_id = auth.uid()
  and public.has_document_access(document_id)
);
