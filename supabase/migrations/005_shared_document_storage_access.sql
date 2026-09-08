drop policy if exists "Users can read own document files" on storage.objects;

create policy "Users can read accessible document files"
on storage.objects for select to authenticated
using (
  bucket_id = 'documents'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1
      from public.documents d
      where d.storage_path = storage.objects.name
        and d.visibility = 'desk'
        and d.desk_id is not null
        and public.is_desk_member(d.desk_id)
    )
  )
);
