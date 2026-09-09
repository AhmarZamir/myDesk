-- Product-readiness controls for Shared Desks, assignments and member management.
-- Keeps collaboration least-privilege: users see what is assigned/shared with them,
-- while desk owners/admins retain the controls needed to manage a workspace.

create or replace function public.is_user_desk_member(p_desk_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.desk_members dm
    where dm.desk_id = p_desk_id
      and dm.user_id = p_user_id
  );
$$;

create or replace function public.desk_role(p_desk_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select dm.role
  from public.desk_members dm
  where dm.desk_id = p_desk_id
    and dm.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.can_manage_desk(p_desk_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.desk_role(p_desk_id) in ('owner', 'admin'), false);
$$;

grant execute on function public.is_user_desk_member(uuid, uuid) to authenticated;
grant execute on function public.desk_role(uuid) to authenticated;
grant execute on function public.can_manage_desk(uuid) to authenticated;

create or replace function public.get_my_desks()
returns table (
  id uuid,
  name text,
  type text,
  owner_id uuid,
  role text,
  invite_code text,
  joined_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    d.id,
    d.name,
    d.type,
    d.owner_id,
    dm.role,
    case when dm.role in ('owner', 'admin') then d.invite_code else null end,
    dm.joined_at,
    d.created_at
  from public.desk_members dm
  join public.desks d on d.id = dm.desk_id
  where dm.user_id = auth.uid()
  order by dm.joined_at desc;
$$;

grant execute on function public.get_my_desks() to authenticated;

create or replace function public.rotate_desk_invite(p_desk_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
begin
  if not public.can_manage_desk(p_desk_id) then
    raise exception 'Only desk owners and admins can rotate invite codes';
  end if;
  new_code := public.generate_invite_code();
  update public.desks set invite_code = new_code where id = p_desk_id;
  return new_code;
end;
$$;

grant execute on function public.rotate_desk_invite(uuid) to authenticated;

create or replace function public.leave_desk(p_desk_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_role text;
begin
  caller_role := public.desk_role(p_desk_id);
  if caller_role is null then
    raise exception 'You are not a member of this desk';
  end if;
  if caller_role = 'owner' then
    raise exception 'Desk owners must delete the desk or transfer ownership before leaving';
  end if;
  delete from public.desk_members
  where desk_id = p_desk_id and user_id = auth.uid();
end;
$$;

grant execute on function public.leave_desk(uuid) to authenticated;

create or replace function public.delete_desk(p_desk_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.owns_desk(p_desk_id) then
    raise exception 'Only the desk owner can delete this desk';
  end if;
  delete from public.desks where id = p_desk_id;
end;
$$;

grant execute on function public.delete_desk(uuid) to authenticated;

create or replace function public.set_desk_member_role(
  p_desk_id uuid,
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.owns_desk(p_desk_id) then
    raise exception 'Only the desk owner can change member roles';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'The owner role cannot be changed here';
  end if;
  if p_role not in ('admin', 'member', 'viewer') then
    raise exception 'Invalid role';
  end if;
  update public.desk_members
  set role = p_role
  where desk_id = p_desk_id and user_id = p_user_id;
  if not found then
    raise exception 'Member not found';
  end if;
end;
$$;

grant execute on function public.set_desk_member_role(uuid, uuid, text) to authenticated;

create or replace function public.remove_desk_member(
  p_desk_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_role text;
begin
  if not public.can_manage_desk(p_desk_id) then
    raise exception 'Only desk owners and admins can remove members';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Use Leave desk to remove yourself';
  end if;
  select role into target_role
  from public.desk_members
  where desk_id = p_desk_id and user_id = p_user_id;
  if target_role is null then
    raise exception 'Member not found';
  end if;
  if target_role = 'owner' then
    raise exception 'The desk owner cannot be removed';
  end if;
  if public.desk_role(p_desk_id) = 'admin' and target_role = 'admin' then
    raise exception 'Admins cannot remove other admins';
  end if;
  delete from public.desk_members
  where desk_id = p_desk_id and user_id = p_user_id;
end;
$$;

grant execute on function public.remove_desk_member(uuid, uuid) to authenticated;

drop policy if exists "Document owners can manage access" on public.document_access;
create policy "Document owners can manage access"
on public.document_access for all to authenticated
using (public.owns_document(document_id))
with check (
  public.owns_document(document_id)
  and granted_by = auth.uid()
  and exists (
    select 1
    from public.documents d
    where d.id = document_id
      and d.visibility = 'custom'
      and d.desk_id is not null
      and public.is_user_desk_member(d.desk_id, user_id)
  )
);

drop policy if exists "Desk members can view bills" on public.bills;
drop policy if exists "Relevant users can view bills" on public.bills;
create policy "Relevant users can view bills"
on public.bills for select to authenticated
using (
  owner_id = auth.uid()
  or assigned_to = auth.uid()
  or (desk_id is not null and public.can_manage_desk(desk_id))
);

drop policy if exists "Users can create bills" on public.bills;
drop policy if exists "Users can create valid bills" on public.bills;
create policy "Users can create valid bills"
on public.bills for insert to authenticated
with check (
  owner_id = auth.uid()
  and (desk_id is null or public.is_desk_member(desk_id))
  and (
    assigned_to is null
    or assigned_to = auth.uid()
    or (desk_id is not null and public.is_user_desk_member(desk_id, assigned_to))
  )
);

drop policy if exists "Owners and assignees can update bills" on public.bills;
drop policy if exists "Owners assignees and managers can update bills" on public.bills;
create policy "Owners assignees and managers can update bills"
on public.bills for update to authenticated
using (
  owner_id = auth.uid()
  or assigned_to = auth.uid()
  or (desk_id is not null and public.can_manage_desk(desk_id))
)
with check (
  owner_id = auth.uid()
  or assigned_to = auth.uid()
  or (desk_id is not null and public.can_manage_desk(desk_id))
);

drop policy if exists "Desk members can view tasks" on public.tasks;
drop policy if exists "Relevant users can view tasks" on public.tasks;
create policy "Relevant users can view tasks"
on public.tasks for select to authenticated
using (
  creator_id = auth.uid()
  or assignee_id = auth.uid()
  or (desk_id is not null and public.can_manage_desk(desk_id))
);

drop policy if exists "Users can create tasks" on public.tasks;
drop policy if exists "Users can create valid tasks" on public.tasks;
create policy "Users can create valid tasks"
on public.tasks for insert to authenticated
with check (
  creator_id = auth.uid()
  and (desk_id is null or public.is_desk_member(desk_id))
  and (
    assignee_id is null
    or assignee_id = auth.uid()
    or (desk_id is not null and public.is_user_desk_member(desk_id, assignee_id))
  )
);

drop policy if exists "Creators and assignees can update tasks" on public.tasks;
drop policy if exists "Creators assignees and managers can update tasks" on public.tasks;
create policy "Creators assignees and managers can update tasks"
on public.tasks for update to authenticated
using (
  creator_id = auth.uid()
  or assignee_id = auth.uid()
  or (desk_id is not null and public.can_manage_desk(desk_id))
)
with check (
  creator_id = auth.uid()
  or assignee_id = auth.uid()
  or (desk_id is not null and public.can_manage_desk(desk_id))
);
