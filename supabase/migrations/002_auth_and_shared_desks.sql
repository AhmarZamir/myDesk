create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.desks
  add column if not exists invite_code text unique;

create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));
    exit when not exists (select 1 from public.desks where invite_code = candidate);
  end loop;
  return candidate;
end;
$$;

alter table public.desks
  alter column invite_code set default public.generate_invite_code();

update public.desks
set invite_code = public.generate_invite_code()
where invite_code is null;

alter table public.desks
  alter column invite_code set not null;

create or replace function public.create_desk(p_name text, p_type text default 'custom')
returns public.desks
language plpgsql
security definer set search_path = public
as $$
declare
  created_desk public.desks;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if length(trim(p_name)) < 2 then
    raise exception 'Desk name must contain at least 2 characters';
  end if;

  insert into public.desks (name, type, owner_id)
  values (trim(p_name), coalesce(nullif(trim(p_type), ''), 'custom'), auth.uid())
  returning * into created_desk;

  insert into public.desk_members (desk_id, user_id, role)
  values (created_desk.id, auth.uid(), 'owner');

  insert into public.activity_events (desk_id, actor_id, event_type, entity_type, entity_id, summary)
  values (created_desk.id, auth.uid(), 'desk_created', 'desk', created_desk.id, 'Created ' || created_desk.name || ' desk');

  return created_desk;
end;
$$;

create or replace function public.join_desk(p_invite_code text)
returns public.desks
language plpgsql
security definer set search_path = public
as $$
declare
  target_desk public.desks;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into target_desk
  from public.desks
  where invite_code = upper(trim(p_invite_code));

  if target_desk.id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.desk_members (desk_id, user_id, role)
  values (target_desk.id, auth.uid(), 'member')
  on conflict (desk_id, user_id) do nothing;

  insert into public.activity_events (desk_id, actor_id, event_type, entity_type, entity_id, summary)
  values (target_desk.id, auth.uid(), 'member_joined', 'desk', target_desk.id, 'A member joined the desk');

  return target_desk;
end;
$$;

create policy "Users can insert own profile"
on public.profiles for insert
with check (auth.uid() = id);

grant usage on schema public to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.desks to authenticated;
grant select, insert, update, delete on public.desk_members to authenticated;
grant select, insert, update, delete on public.documents to authenticated;
grant select, insert, update, delete on public.bills to authenticated;
grant select, insert, update, delete on public.tasks to authenticated;
grant select, insert, update, delete on public.khata_entries to authenticated;
grant select, insert on public.activity_events to authenticated;
grant execute on function public.create_desk(text, text) to authenticated;
grant execute on function public.join_desk(text) to authenticated;
