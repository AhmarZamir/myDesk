-- Richer collaboration notifications for myDesk.
-- Complements task/khata notifications from migration 014.

create or replace function public.notify_bill_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.assigned_to is not null and new.assigned_to <> new.owner_id then
      insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
      values (new.assigned_to, new.owner_id, 'general', 'Bill assigned to you', new.title || ' · Rs. ' || new.amount::text, new.id);
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.owner_id <> auth.uid() then
      insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
      values (new.owner_id, auth.uid(), 'general', 'Bill status updated', new.title || ' · ' || new.status, new.id);
    end if;
    if new.assigned_to is not null and new.assigned_to <> auth.uid() and new.assigned_to <> new.owner_id then
      insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
      values (new.assigned_to, auth.uid(), 'general', 'Bill status updated', new.title || ' · ' || new.status, new.id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_bill_change on public.bills;
create trigger trg_notify_bill_change
after insert or update of status, assigned_to on public.bills
for each row execute function public.notify_bill_change();

create or replace function public.notify_document_access()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
begin
  select title into v_title from public.documents where id = new.document_id;
  if new.user_id <> new.granted_by then
    insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
    values (new.user_id, new.granted_by, 'document', 'Document shared with you', coalesce(v_title, 'Shared document'), new.document_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_document_access on public.document_access;
create trigger trg_notify_document_access
after insert on public.document_access
for each row execute function public.notify_document_access();

create or replace function public.notify_desk_document()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.desk_id is not null and new.visibility = 'desk' then
    insert into public.notifications(recipient_id, actor_id, kind, title, body, entity_id)
    select dm.user_id, new.owner_id, 'document', 'New document in Shared Desk', new.title, new.id
    from public.desk_members dm
    where dm.desk_id = new.desk_id and dm.user_id <> new.owner_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_desk_document on public.documents;
create trigger trg_notify_desk_document
after insert on public.documents
for each row execute function public.notify_desk_document();
