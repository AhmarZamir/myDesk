create or replace function public.is_desk_member(p_desk_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.desk_members
    where desk_id = p_desk_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.owns_desk(p_desk_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.desks
    where id = p_desk_id
      and owner_id = auth.uid()
  );
$$;

grant execute on function public.is_desk_member(uuid) to authenticated;
grant execute on function public.owns_desk(uuid) to authenticated;

drop policy if exists "Members can view desks" on public.desks;
create policy "Members can view desks"
on public.desks for select
using (owner_id = auth.uid() or public.is_desk_member(id));

drop policy if exists "Members can view desk membership" on public.desk_members;
create policy "Members can view desk membership"
on public.desk_members for select
using (user_id = auth.uid() or public.owns_desk(desk_id));

drop policy if exists "Owners can manage desk membership" on public.desk_members;
create policy "Owners can manage desk membership"
on public.desk_members for all
using (public.owns_desk(desk_id))
with check (public.owns_desk(desk_id));

drop policy if exists "Users can view accessible documents" on public.documents;
create policy "Users can view accessible documents"
on public.documents for select
using (owner_id = auth.uid() or (desk_id is not null and public.is_desk_member(desk_id)));

drop policy if exists "Desk members can view bills" on public.bills;
create policy "Desk members can view bills"
on public.bills for select
using (owner_id = auth.uid() or (desk_id is not null and public.is_desk_member(desk_id)));

drop policy if exists "Desk members can view tasks" on public.tasks;
create policy "Desk members can view tasks"
on public.tasks for select
using (
  creator_id = auth.uid()
  or assignee_id = auth.uid()
  or (desk_id is not null and public.is_desk_member(desk_id))
);

drop policy if exists "Desk members can view activity" on public.activity_events;
create policy "Desk members can view activity"
on public.activity_events for select
using (actor_id = auth.uid() or (desk_id is not null and public.is_desk_member(desk_id)));
