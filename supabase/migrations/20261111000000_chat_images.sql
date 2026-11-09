-- Extend private chat media storage to support image attachments.
alter table public.messages
  drop constraint if exists messages_message_type_check;

alter table public.messages
  add constraint messages_message_type_check
  check (message_type in ('text', 'voice', 'video_circle', 'image'));

update storage.buckets
set allowed_mime_types = array[
  'audio/mp4', 'audio/aac', 'audio/m4a',
  'video/mp4', 'video/quicktime',
  'image/jpeg', 'image/png', 'image/webp', 'image/heic'
]
where id = 'chat-media';
