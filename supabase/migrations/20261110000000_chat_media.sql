-- Novagram private chat media: voice notes and short video circles.
alter table public.messages
  add column if not exists message_type text not null default 'text',
  add column if not exists media_path text,
  add column if not exists media_duration_ms integer;

alter table public.messages
  drop constraint if exists messages_message_type_check;
alter table public.messages
  add constraint messages_message_type_check
  check (message_type in ('text', 'voice', 'video_circle'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media',
  'chat-media',
  false,
  52428800,
  array['audio/mp4', 'audio/aac', 'audio/m4a', 'video/mp4', 'video/quicktime']
)
on conflict (id) do update
set public = false,
    file_size_limit = 52428800,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Chat members read chat media" on storage.objects;
create policy "Chat members read chat media"
on storage.objects for select to authenticated
using (
  bucket_id = 'chat-media'
  and exists (
    select 1 from public.chat_members m
    where m.chat_id::text = (storage.foldername(name))[1]
      and m.user_id = auth.uid()
  )
);

drop policy if exists "Chat members upload own chat media" on storage.objects;
create policy "Chat members upload own chat media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[2] = auth.uid()::text
  and exists (
    select 1 from public.chat_members m
    where m.chat_id::text = (storage.foldername(name))[1]
      and m.user_id = auth.uid()
  )
);
