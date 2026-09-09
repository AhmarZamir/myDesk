-- myDesk Buddies: persistent person-to-person connections independent of Shared Desks.
-- Buddies can be reused for direct document sharing, bilateral Khata visibility,
-- and can be added into Shared Desks by desk managers.

create table if not exists public.buddy_invites (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null default (now() + interval '30 days'),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.buddy_connections (
  user_low uuid not null references public.profiles(id) on delete cascade,
  user_high uuid not null references public.profiles(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low, user_high),
  check (user_low <> user_high),
  check (user_low::text < user_high::text)
);

alter table public.buddy_invites enable row level security;
alter table public.buddy_connections enable row level security;

create or replace function public.are_buddies(p_user_a uuid, p_user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.buddy_connections bc
    where bc.user_low = least(p_user_a, p_user_b)
      and bc.user_high = greatest(p_user_a, p_user_b)
  );
$$;

grant execute on function public.are_buddies(uuid, uuid) to authenticated;

create or replace function public.create_buddy_invite()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform public.ensure_current_profile();
  v_token := lower(replace(gen_random_uuid()::text, '-', ''));
  insert into public.buddy_invites(inviter_id, token) values (auth.uid(), v_token);
  return v_token;
end;
$$;

grant execute on function public.create_buddy_invite() to authenticated;

create or replace function public.accept_buddy_invite(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inviter uuid;
  v_low uuid;
  v_high uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform public.ensure_current_profile();

  select inviter_id into v_inviter
  from public.buddy_invites
  where token = lower(trim(p_token))
    and revoked_at is null
    and expires_at > now()
  order by created_at desc
  limit 1;

  if v_inviter is null then raise exception 'Invite is invalid or expired'; end if;
  if v_inviter = auth.uid() then raise exception 'You cannot add yourself as a buddy'; end if;

  v_low := least(v_inviter, auth.uid());
  v_high := greatest(v_inviter, auth.uid());

  insert into public.buddy_connections(user_low, user_high, created_by)
  values (v_low, v_high, v_inviter)
  on conflict do nothing;

  update public.buddy_invites set revoked_at = now()
  where token = lower(trim(p_token));

  return jsonb_build_object('buddy_user_id', v_inviter, 'connected', true);
end;
$$;

grant execute on function public.accept_buddy_invite(text) to authenticated;

create or replace function public.get_my_buddies()
returns table (
  user_id uuid,
  full_name text,
  avatar_url text,
  connected_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    case when bc.user_low = auth.uid() then bc.user_high else bc.user_low end as user_id,
    coalesce(nullif(p.full_name, ''), 'Buddy') as full_name,
    p.avatar_url,
    bc.created_at
  from public.buddy_connections bc
  join public.profiles p
    on p.id = case when bc.user_low = auth.uid() then bc.user_high else bc.user_low end
  where bc.user_low = auth.uid() or bc.user_high = auth.uid()
  order by bc.created_at desc;
$$;

grant execute on function public.get_my_buddies() to authenticated;

create or replace function public.remove_buddy(p_buddy_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.buddy_connections
  where user_low = least(auth.uid(), p_buddy_user_id)
    and user_high = greatest(auth.uid(), p_buddy_user_id);
end;
$$;

grant execute on function public.remove_buddy(uuid) to authenticated;

create or replace function public.add_buddy_to_desk(p_desk_id uuid, p_buddy_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.can_manage_desk(p_desk_id) then
    raise exception 'Only desk owners and admins can add members';
  end if;
  if not public.are_buddies(auth.uid(), p_buddy_user_id) then
    raise exception 'This person is not your myDesk Buddy';
  end if;
  insert into public.desk_members(desk_id, user_id, role)
  values (p_desk_id, p_buddy_user_id, 'member')
  on conflict (desk_id, user_id) do nothing;
end;
$$;

grant execute on function public.add_buddy_to_desk(uuid, uuid) to authenticated;

-- Direct custom document sharing is allowed with either a current desk member
-- or a Buddy. A Shared Desk is no longer required for custom-person sharing.
drop policy if exists "Document owners can manage access" on public.document_access;
create policy "Document owners can manage access"
on public.document_access for all to authenticated
using (public.owns_document(document_id))
with check (
  public.owns_document(document_id)
  and granted_by = auth.uid()
  and (
    public.are_buddies(auth.uid(), user_id)
    or exists (
      select 1 from public.documents d
      where d.id = document_id
        and d.desk_id is not null
        and public.is_user_desk_member(d.desk_id, user_id)
    )
  )
);

-- Override the earlier desk-only access helper so a direct Buddy grant works
-- without weakening the rule for Shared Desk recipients.
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
      and (
        (d.desk_id is not null and public.is_user_desk_member(d.desk_id, auth.uid()))
        or (d.desk_id is null and public.are_buddies(d.owner_id, auth.uid()))
      )
  );
$$;

grant execute on function public.has_document_access(uuid) to authenticated;

-- Khata can optionally be linked to a Buddy. The creator owns edits; the Buddy
-- receives read-only visibility of the same ledger entry.
alter table public.khata_entries
  add column if not exists buddy_user_id uuid references public.profiles(id) on delete set null;

create index if not exists idx_khata_buddy on public.khata_entries(buddy_user_id);

drop policy if exists "Khata participants can view entries" on public.khata_entries;
drop policy if exists "Users can view own Khata entries" on public.khata_entries;
create policy "Khata creator and buddy can view entries"
on public.khata_entries for select to authenticated
using (created_by = auth.uid() or buddy_user_id = auth.uid());

drop policy if exists "Users can create khata entries" on public.khata_entries;
drop policy if exists "Users can create own Khata entries" on public.khata_entries;
create policy "Users can create buddy-aware Khata entries"
on public.khata_entries for insert to authenticated
with check (
  created_by = auth.uid()
  and (
    buddy_user_id is null
    or public.are_buddies(auth.uid(), buddy_user_id)
  )
);

drop policy if exists "Participants can update khata entries" on public.khata_entries;
drop policy if exists "Users can update own Khata entries" on public.khata_entries;
create policy "Khata creator can update entries"
on public.khata_entries for update to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists "Users can delete own Khata entries" on public.khata_entries;
create policy "Khata creator can delete entries"
on public.khata_entries for delete to authenticated
using (created_by = auth.uid());
