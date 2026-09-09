-- Security follow-up discovered during user-flow verification.
-- 1) Removed desk members must lose custom document access immediately.
-- 2) Invite codes are not queryable from the raw desks table by ordinary members.
-- 3) Viewer-role members are read-only for desk-linked content creation.

create or replace function public.has_document_access(p_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.document_access da
    join public.documents d on d.id = da.document_id
    where da.document_id = p_document_id
      and da.user_id = auth.uid()
      and d.desk_id is not null
      and public.is_user_desk_member(d.desk_id, auth.uid())
  );
$$;

grant execute on function public.has_document_access(uuid) to authenticated;

-- The app now obtains desks through get_my_desks(), which redacts invite codes
-- for non-managers. Prevent bypassing that by querying the table directly.
revoke select on public.desks from authenticated;

drop policy if exists "Users can create own documents" on public.documents;
create policy "Users can create valid documents"
on public.documents for insert to authenticated
with check (
  owner_id = auth.uid()
  and (
    desk_id is null
    or (
      public.is_desk_member(desk_id)
      and coalesce(public.desk_role(desk_id), 'viewer') <> 'viewer'
    )
  )
);

drop policy if exists "Owners can update documents" on public.documents;
create policy "Owners can update valid documents"
on public.documents for update to authenticated
using (owner_id = auth.uid())
with check (
  owner_id = auth.uid()
  and (
    desk_id is null
    or (
      public.is_desk_member(desk_id)
      and coalesce(public.desk_role(desk_id), 'viewer') <> 'viewer'
    )
  )
);

-- Recreate insert policies with viewer-role protection.
drop policy if exists "Users can create valid bills" on public.bills;
create policy "Users can create valid bills"
on public.bills for insert to authenticated
with check (
  owner_id = auth.uid()
  and (
    desk_id is null
    or (
      public.is_desk_member(desk_id)
      and coalesce(public.desk_role(desk_id), 'viewer') <> 'viewer'
    )
  )
  and (
    assigned_to is null
    or assigned_to = auth.uid()
    or (desk_id is not null and public.is_user_desk_member(desk_id, assigned_to))
  )
);

drop policy if exists "Users can create valid tasks" on public.tasks;
create policy "Users can create valid tasks"
on public.tasks for insert to authenticated
with check (
  creator_id = auth.uid()
  and (
    desk_id is null
    or (
      public.is_desk_member(desk_id)
      and coalesce(public.desk_role(desk_id), 'viewer') <> 'viewer'
    )
  )
  and (
    assignee_id is null
    or assignee_id = auth.uid()
    or (desk_id is not null and public.is_user_desk_member(desk_id, assignee_id))
  )
);
