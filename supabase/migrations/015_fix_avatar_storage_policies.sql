-- Repair avatar Storage permissions for both first upload and upsert/replacement.
-- Each authenticated user may only manage objects under avatars/<their-user-id>/...

-- Keep the bucket public for rendering profile photos in the UI.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = true,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- Drop both the original policies and any previous repair policies so this migration is idempotent.
drop policy if exists "Users upload own avatar" on storage.objects;
drop policy if exists "Users update own avatar" on storage.objects;
drop policy if exists "Users delete own avatar" on storage.objects;
drop policy if exists "Users read own avatar metadata" on storage.objects;

-- Supabase Storage upsert can require SELECT in addition to INSERT/UPDATE.
create policy "Users read own avatar metadata"
on storage.objects for select to authenticated
using (
  bucket_id = 'avatars'
  and name like auth.uid()::text || '/%'
);

create policy "Users upload own avatar"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and name like auth.uid()::text || '/%'
);

create policy "Users update own avatar"
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and name like auth.uid()::text || '/%'
)
with check (
  bucket_id = 'avatars'
  and name like auth.uid()::text || '/%'
);

create policy "Users delete own avatar"
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and name like auth.uid()::text || '/%'
);
