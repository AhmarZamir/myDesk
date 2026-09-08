-- Fine-grained document sharing for myDesk.
-- Supports private, entire desk, or selected desk members.

create table if not exists public.document_access (
  document_id uuid not null references public.documents(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  granted_by uuid not null references public.profiles(id) on delete cascade,
  granted_at timestamptz not null default now(),
  primary key (document_id, user_id)
);

alter table public.document_access enable row level security;

create or replace function public.owns_document(p_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.documents d
    where d.id = p_document_id and d.owner_id = auth.uid()
  );
$$;

create or replace function public.has_document_access(p_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.document_access da
    where da.document_id = p_document_id and da.user_id = auth.uid()
  );
$$;

grant execute on function public.owns_document(uuid) to authenticated;
grant execute on function public.has_document_access(uuid) to authenticated;

create policy "Document owners can manage access"
on public.document_access for all to authenticated
using (public.owns_document(document_id))
with check (public.owns_document(document_id) and granted_by = auth.uid());

create policy "Recipients can read own grants"
on public.document_access for select to authenticated
using (user_id = auth.uid());

-- Replace document read policy with private / desk / selected-person semantics.
drop policy if exists "Users can view accessible documents" on public.documents;
create policy "Users can view accessible documents"
on public.documents for select to authenticated
using (
  owner_id = auth.uid()
  or (
    visibility = 'desk'
    and desk_id is not null
    and public.is_desk_member(desk_id)
  )
  or (
    visibility = 'custom'
    and public.has_document_access(id)
  )
);

-- Storage access must mirror metadata access.
drop policy if exists "Users can read accessible document files" on storage.objects;
create policy "Users can read accessible document files"
on storage.objects for select to authenticated
using (
  bucket_id = 'documents'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1 from public.documents d
      where d.storage_path = storage.objects.name
        and (
          (d.visibility = 'desk' and d.desk_id is not null and public.is_desk_member(d.desk_id))
          or (d.visibility = 'custom' and public.has_document_access(d.id))
        )
    )
  )
);

-- Return members only after confirming the caller belongs to the desk.
create or replace function public.get_desk_members(p_desk_id uuid)
returns table (
  user_id uuid,
  full_name text,
  role text,
  is_me boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    dm.user_id,
    coalesce(nullif(p.full_name, ''), 'Member') as full_name,
    dm.role,
    dm.user_id = auth.uid() as is_me
  from public.desk_members dm
  join public.profiles p on p.id = dm.user_id
  where dm.desk_id = p_desk_id
    and public.is_desk_member(p_desk_id)
  order by (dm.user_id = auth.uid()) desc, p.full_name nulls last, dm.joined_at;
$$;

grant select, insert, update, delete on public.document_access to authenticated;
grant execute on function public.get_desk_members(uuid) to authenticated;
