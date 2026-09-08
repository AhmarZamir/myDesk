alter table khata_entries
  add column if not exists counterparty_name text,
  add column if not exists direction text not null default 'receivable'
    check (direction in ('receivable','payable'));

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "Authenticated users can upload document files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can read own document files"
on storage.objects for select to authenticated
using (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own document files"
on storage.objects for update to authenticated
using (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete own document files"
on storage.objects for delete to authenticated
using (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Owners can delete bills" on bills for delete
using (owner_id = auth.uid());

create policy "Creators can delete tasks" on tasks for delete
using (creator_id = auth.uid());

create policy "Creators can delete khata entries" on khata_entries for delete
using (created_by = auth.uid());
