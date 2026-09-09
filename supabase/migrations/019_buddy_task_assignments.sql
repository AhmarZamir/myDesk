-- Allow direct task assignment to current Buddies without requiring a Shared Desk.
-- Shared Desk assignments remain restricted to current members of that desk.

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
    or (desk_id is null and public.are_buddies(auth.uid(), assignee_id))
  )
);
