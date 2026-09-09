-- Notifications, navigation badge counts, and profile-avatar storage.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  kind text not null check (kind in ('task','khata','document','desk','buddy','general')),
  title text not null,
  body text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_recipient_created
  on public.notifications(recipient_id, created_at desc);
create index if not exists idx_notifications_recipient_unread
  on public.notifications(recipient_id, read_at) where read_at is null;

alter table public.notifications enable row level security;

drop policy if exists "Users read own notifications" on public.notifications;
create policy "Users read own notifications"
on public.notifications for select to authenticated
using (recipient_id = auth.uid());

drop policy if exists "Users mark own notifications read" on public.notifications;
create policy "Users mark own notifications read"
on public.notifications for update to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

-- Clients never insert notifications directly. Triggers/functions do that.
revoke insert, delete on public.notifications from authenticated;

create or replace function public.notify_task_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.assignee_id is not null and new.assignee_id <> new.creator_id then
      insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
      values (new.assignee_id, new.creator_id, 'task', 'New task assigned', new.title, new.id);
    end if;
    return new;
  end if;

  if new.assignee_id is distinct from old.assignee_id
     and new.assignee_id is not null
     and new.assignee_id <> new.creator_id then
    insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
    values (new.assignee_id, auth.uid(), 'task', 'Task assigned to you', new.title, new.id);
  end if;

  if new.status is distinct from old.status then
    if new.creator_id <> auth.uid() then
      insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
      values (new.creator_id, auth.uid(), 'task', 'Task status updated', new.title || ' · ' || replace(new.status, '_', ' '), new.id);
    end if;
    if new.assignee_id is not null and new.assignee_id <> auth.uid() and new.assignee_id <> new.creator_id then
      insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
      values (new.assignee_id, auth.uid(), 'task', 'Task status updated', new.title || ' · ' || replace(new.status, '_', ' '), new.id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_task_change on public.tasks;
create trigger trg_notify_task_change
after insert or update of assignee_id, status on public.tasks
for each row execute function public.notify_task_change();

create or replace function public.notify_khata_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.buddy_user_id is not null and new.buddy_user_id <> new.created_by then
      insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
      values (
        new.buddy_user_id,
        new.created_by,
        'khata',
        'Khata updated with you',
        coalesce(new.note, '') || case when coalesce(new.note, '') = '' then '' else ' · ' end || 'Rs. ' || new.amount::text,
        new.id
      );
    end if;
    return new;
  end if;

  if new.status is distinct from old.status and new.buddy_user_id is not null then
    insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
    values (
      new.buddy_user_id,
      auth.uid(),
      'khata',
      'Khata status updated',
      coalesce(new.counterparty_name, 'Khata') || ' · ' || new.status,
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_khata_change on public.khata_entries;
create trigger trg_notify_khata_change
after insert or update of status on public.khata_entries
for each row execute function public.notify_khata_change();

create or replace function public.notification_counts()
returns table(task_count bigint, khata_count bigint, total_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select
    count(*) filter (where kind = 'task') as task_count,
    count(*) filter (where kind = 'khata') as khata_count,
    count(*) as total_count
  from public.notifications
  where recipient_id = auth.uid() and read_at is null;
$$;

grant execute on function public.notification_counts() to authenticated;

create or replace function public.mark_notifications_read(p_kind text default null)
returns void
language sql
security definer
set search_path = public
as $$
  update public.notifications
  set read_at = now()
  where recipient_id = auth.uid()
    and read_at is null
    and (p_kind is null or kind = p_kind);
$$;

grant execute on function public.mark_notifications_read(text) to authenticated;

-- Avatar bucket. Profile photos are public by design so Buddy/Desk member avatars
-- can render without issuing signed URLs. Users may only write inside their own folder.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Users upload own avatar" on storage.objects;
create policy "Users upload own avatar"
on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users update own avatar" on storage.objects;
create policy "Users update own avatar"
on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users delete own avatar" on storage.objects;
create policy "Users delete own avatar"
on storage.objects for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Enable Realtime for notification badge refresh when supported.
do $$
begin
  begin
    alter publication supabase_realtime add table public.notifications;
  exception when duplicate_object then null;
  end;
end $$;
