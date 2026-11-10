-- Repair media schema and bucket MIME types in a forward-only migration.
-- The earlier image migration could run before the chat-media bucket existed.
alter table public.messages
  add column if not exists message_type text not null default 'text',
  add column if not exists media_path text,
  add column if not exists media_duration_ms integer;

alter table public.messages
  drop constraint if exists messages_message_type_check;
alter table public.messages
  add constraint messages_message_type_check
  check (message_type in ('text', 'voice', 'video_circle', 'image'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media',
  'chat-media',
  false,
  52428800,
  array[
    'audio/mp4', 'audio/aac', 'audio/m4a',
    'video/mp4', 'video/quicktime',
    'image/jpeg', 'image/png', 'image/webp', 'image/heic'
  ]
)
on conflict (id) do update
set public = false,
    file_size_limit = 52428800,
    allowed_mime_types = excluded.allowed_mime_types;
